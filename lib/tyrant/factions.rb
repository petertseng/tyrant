require 'tyrant'
require 'tyrant/sanitize'

class Tyrant
  def update_rankings; end
  def update_conquest; end

  def self.format_faction(data)
    name = Tyrant::sanitize_or_default(data['name'], '(nil)')
    members = data['num_members']
    activity = data['activity_level']
    level = data['level']
    fp = data['rating']
    cr = data['conquest_rating']
    wl = "#{data['wins']}/#{data['losses']} W/L"
    infamy = data['infamy']
    inf = infamy.to_i == 0 ? '' : ", Infamy: #{infamy}"
    tiles = data['num_territories']
    part1 = "#{name}: #{members} members (#{activity}% active)"
    part2 = "Level #{level}, #{fp} FP, #{wl}, #{cr} CR, #{tiles} tiles"
    return "#{part1}, #{part2}#{inf}"
  end

  def faction_data(target_id); return {}; end
end
