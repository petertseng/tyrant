require 'tyrant'

class Tyrant
  def faction_members
    path = "faction_members_#{faction_id}"
    json = make_cached_request(
      path,
      'getFactionMembers',
      "faction_id=#{faction_id}"
    )
    return json['members']
  end
end
