require 'date'

require 'tyrant'
require 'tyrant/sanitize'
require 'tyrant/time'

class Tyrant
  # Returns an array of some data about this war.
  # See names of variables used in the return value.
  def war_info(war)
    id = war['faction_war_id']
    attacker_id = war['attacker_faction_id'].to_i
    defender_id = war['defender_faction_id'].to_i
    start = war['start_time'].to_i
    finish = start + war['duration'].to_i * Time::HOUR
    atk_pts = war['attacker_points'].to_i
    def_pts = war['defender_points'].to_i
    if attacker_id.to_i == faction_id
      attacker_name = faction_name
      defender_name = war['name']
      diff = atk_pts - def_pts
      fp = war['attacker_rating_change']
    elsif defender_id.to_i == faction_id
      attacker_name = war['name']
      defender_name = faction_name
      diff = def_pts - atk_pts
      fp = war['defender_rating_change']
    else
      attacker_name = war['name']
      defender_name = 'WTF wrong faction???'
      diff = 0
      fp = 0
    end

    win = war['victory']
    return [
      id,
      attacker_name, defender_name,
      atk_pts, def_pts,
      diff,
      start, finish,
      fp, win
    ]
  end

  def format_wars(wars)
    return wars.map { |war|
      data = war_info(war)

      data[1] = Tyrant::sanitize_string(data[1])
      data[2] = Tyrant::sanitize_string(data[2])
      end_time = data[7]
      fp_change = data[8]

      now = ::Time.now.to_i
      if end_time <= now
        # Past war:
        time_str = Time::format_time_days(now - end_time) + ' ago'
        fp_str = ', %+d FP' % fp_change if fp_change
      else
        # Current war:
        time_str = Time::format_time(end_time - now) + ' left'
        fp_str = ''
      end

      data = data.slice(0, 6) + [time_str, fp_str]

      '%10d - %s vs %s %d-%d (%+d) %s%s' % data
    }.join("\n")
  end

  def current_wars
    json = make_request('getActiveFactionWars')['wars']
    return json.empty? ? [] : json.values
  end

  def old_wars(days = 7, cache: true)
    if cache
      today = ::Time.now.strftime('%y%m%d_%H')
      path = "old_wars/#{faction_id}/#{today}"
      json = make_cached_request(path, 'getOldFactionWars')
    else
      json = make_request('getOldFactionWars')
    end

    return json['wars'] if days.nil?

    return json['wars'].select { |war|
      (::Time.now.to_i - war['start_time'].to_i).to_f / 86400.0 < days
    }
  end

  # Returns Hash[ID->[rankings]] of war rankings.
  # Will include both factions if who == :both,
  # only this player's faction if who == :us,
  # and only this player's opponent if who == :them.
  def war_rankings(war, who = :us, cache: true)
    path = "wars/#{faction_id}/#{war}"
    if cache
      json = make_cached_request(
        path,
        'getFactionWarRankings',
        "faction_war_id=#{war}"
      )
    else
      json = make_request('getFactionWarRankings', "faction_war_id=#{war}")
    end

    # One or both factions' rankings may be missing due to disband or something.
    # If they disbanded before we could fight, json['rankings'] is empty!
    return {} if json['rankings'].empty?

    # Otherwise, a disbanded faction's stats will also be missing:
    if who == :us
      rankings = json['rankings'][faction_id.to_s] || []
      return {faction_id => rankings}
    elsif who == :them
      others = json['rankings'].keys.reject { |k| k == faction_id.to_s }
      raise "Too many others in this war: #{others}" unless others.size == 1
      other = others.first
      rankings = json['rankings'][other] || []
      return {other.to_i => rankings}
    elsif who == :both
      return json['rankings']
    else
      raise 'Unknown who ' + who
    end
  end
end
