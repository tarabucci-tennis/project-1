# "This person record was merged into that one" (see UserMerge), so old
# profile links forward to the kept record.
class MergedUser < ApplicationRecord
  # The record an old id ended up in, following merges of merges.
  def self.current_id_for(id, hops: 5)
    current = id.to_i
    hops.times do
      nxt = where(from_user_id: current).pick(:into_user_id)
      return current unless nxt
      current = nxt
    end
    current
  end
end
