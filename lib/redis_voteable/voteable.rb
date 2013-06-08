module RedisVoteable
  module Voteable
    extend ActiveSupport::Concern
    
    included do
      
    end

    module ClassMethods
      def voteable?
        true
      end
      
      # private
      # def build_voter(voter)
      #   tmp = voter.split(':')
      #   tmp[0, tmp.length - 1].constantize.find(tmp.last)
      # end
    end
    
    module InstanceMethods
      def up_votes
        redis.scard prefixed("#{class_key(self)}:#{UP_VOTERS}")
      end
      
      def down_votes
        redis.scard prefixed("#{class_key(self)}:#{DOWN_VOTERS}")
      end
      
      def total_votes
        up_votes + down_votes
      end
      
      # Return the difference between up and and votes.
      # May be negative if there are more down than up votes.
      def tally
        up_votes - down_votes
      end
      
      def up_percentage
        return (up_votes.to_f * 100 / total_votes) unless total_votes == 0
        nil
      end
      
      def down_percentage
        return (down_votes.to_f * 100 / total_votes) unless total_votes == 0
        nil
      end
      
      # Returns true if the voter voted on the +voteable+.
      def voted?(voter)
        up_voted?(voter) || down_voted?(voter)
      end
      
      # Returns :up, :down, or nil.
      def vote_value?(voter)
        return :up   if up_voted?(voter)
        return :down if down_voted?(voter)
        return nil
      end
      
      # Returns true if the voter up voted the +voteable+.
      def up_voted?(voter)
        redis.sismember prefixed("#{class_key(voter)}:#{UP_VOTES}"), "#{class_key(self)}"
      end

      # Returns true if the voter down voted the +voteable+.
      def down_voted?(voter)
        redis.sismember prefixed("#{class_key(voter)}:#{DOWN_VOTES}"), "#{class_key(self)}"
      end
      
      
      # Returns an array of objects that are +voter+s that voted on this 
      # +voteable+. This method can be very slow, as it constructs each
      # object. Also, it assumes that each object has a +find(id)+ method
      # defined (e.g., any ActiveRecord object).
      def voters
        up_voters | down_voters
      end
      
      def up_voters_ids
        voters = redis.smembers prefixed("#{class_key(self)}:#{UP_VOTERS_ID}")        
      end
      
      def up_voters
        voters = redis.smembers prefixed("#{class_key(self)}:#{UP_VOTERS}")
        voters.map do |voter|
          tmp = voter.split(':')
          klass = tmp[0, tmp.length-1].join(':').constantize
          if klass.respond_to?('find')
            klass.find(tmp.last)
          elsif klass.respond_to?('get')
            klass.get(tmp.last)
          else
            nil
          end
        end
      end
      
      def down_voters_ids
        voters = redis.smembers prefixed("#{class_key(self)}:#{DOWN_VOTERS_ID}")        
      end
      
      def down_voters
        voters = redis.smembers prefixed("#{class_key(self)}:#{DOWN_VOTERS}")
        voters.map do |voter|
          tmp = voter.split(':')
          klass = tmp[0, tmp.length-1].join(':').constantize
          if klass.respond_to?('find')
            klass.find(tmp.last)
          elsif klass.respond_to?('get')
            klass.get(tmp.last)
          else
            nil
          end
        end
      end
      
      # Calculates the (lower) bound of the Wilson confidence interval
      # See: http://en.wikipedia.org/wiki/Binomial_proportion_confidence_interval#Wilson_score_interval
      # and: http://www.evanmiller.org/how-not-to-sort-by-average-rating.html
      def confidence(bound = :lower)
        #include Math
        epsilon = 0.5  # Used for Lidstone smoothing
        up   = up_votes + epsilon
        down = down_votes + epsilon
        n = up + down
        if n == 0
          return 0 if n == 0
        end
        z = 1.4395314800662002 # Determines confidence to estimate. 
                               #    1.0364333771448913 = 70%
                               #    1.2815515594600038 = 80%
                               #    1.4395314800662002 = 85%
                               #    1.644853646608357  = 90%
                               #    1.9599639715843482 = 95%
                               #    2.2414027073522136 = 97.5%
        p_hat = 1.0*up/n
        left  = p_hat + z*z/(2*n)
        right = z * Math.sqrt( (p_hat*(1-p_hat) + z*z/(4*n)) / n )
        under = 1 + z*z/n
        return (left - right) / under unless bound == :upper
        return (left + right) / under
        #return Math.sqrt( p_hat + z * z / ( 2 * n ) - z * ( ( p_hat * ( 1 - p_hat ) + z * z / ( 4 * n ) ) / n ) ) / ( 1 + z * z / n )
      end
    end
    
  end
end