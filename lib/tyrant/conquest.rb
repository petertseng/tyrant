require 'date'

require 'tyrant'
require 'tyrant/sanitize'

class Tyrant
  def self.format_signed_number(v, neg, pos)
    return "#{v}#{pos}" if v > 0
    return "#{-v}#{neg}" if v < 0
    return '0'
  end

  def self.format_coord(x, y)
    lat = Tyrant::format_signed_number(x, 'W', 'E')
    long = Tyrant::format_signed_number(y, 'N', 'S')
    return '%3s, %3s' % [lat, long]
  end

  def self.format_tile_short(tile)
    coords = Tyrant::format_coord(tile['x'].to_i, tile['y'].to_i)
    owner = Tyrant::sanitize_or_default(tile['faction_name'], '(neutral)')
    attacker =
      Tyrant::sanitize_or_default(tile['attacking_faction_name'], '(nil)')
    time_left = tile['attack_end_time'].to_i - ::Time.now.to_i
    return "#{tile['system_id']} (#{coords}) #{attacker} vs #{owner}, " +
      "#{Tyrant::Time::format_time(time_left)} left, CR: #{tile['rating']}"
  end

  def self.format_tile(tile, show_ids: false)
    coords = Tyrant.format_coord(tile['x'].to_i, tile['y'].to_i)
    coords << "[#{tile['system_id']}]" if show_ids
    owner = Tyrant::sanitize_or_default(tile['faction_name'], '(neutral)')
    owner << "[#{tile['faction_id']}]" if show_ids
    str = "#{coords}: #{owner}"
    if tile['attack_end_time']
      attacker =
        Tyrant::sanitize_or_default(tile['attacking_faction_name'], '(nil)')
      attacker << "[#{tile['attacking_faction_id']}]" if show_ids
      t = tile['attack_end_time'].to_i - ::Time.now.to_i
      str << ", attacked by #{attacker}, #{Tyrant::Time::format_time(t)} left"
    elsif tile['protection_end_time']
      time = tile['protection_end_time'].to_i
      if time > ::Time.now.to_i
        t = time - ::Time.now.to_i
        str << ", protected for #{Tyrant::Time::format_time(t)}"
      end
    end
    str << ", CR: #{tile['rating']}"
    cap = tile['level_cap'].to_i
    str << ", max level #{cap}" if cap > 0
    return str
  end
end
