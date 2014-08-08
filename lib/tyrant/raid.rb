require 'date'
require 'nokogiri'

require 'tyrant'
require 'tyrant/monkey/nokogiri-get-one'
require 'tyrant/player'

class Tyrant::Raid
  attr_reader :id, :name, :capacity, :health, :hours, :full_honor
  def initialize(id, name, capacity, health, hours, full_honor)
    @id = id
    @name = name
    @capacity = capacity
    @health = health
    @hours = hours
    @full_honor = full_honor
  end

  def seconds; return @hours * 3600; end
end

class Tyrant
  def self.parse_raids(filename)
    raids = [
      Raid.new(0, 'Raid 0 WTF', 1, 1, 1, 1),
    ]
    doc = Nokogiri::XML(File.open(filename, 'r'))
    doc.xpath('//raid').each { |xml|
      id = xml.get_one('id').to_i
      name = xml.get_one('name')
      capacity = xml.get_one('num_players').to_i
      health = xml.get_one('health').to_i
      honor = xml.get_one('total_honor').to_i
      hours = xml.get_one('time').to_i
      raids << Raid.new(id, name, capacity, health, hours, honor)
    }
    return raids
  end

  def raid_info(user_raid_id); return {}; end

  def self.format_raid(raids, json)
    return 'Invalid raid' if not json['raid_id']

    initiator = Tyrant::name_of_id(json['user_raid_id'])

    type = json['raid_id'].to_i
    time_left = json['end_time'] - ::Time.now.to_i
    health_left = json['health'].to_i
    members = json['raid_members'].count

    raid = raids[type]

    if raid
      health_p = 100.0 * health_left.to_f / raid.health.to_f
      health_p = health_p.round

      # We want to shorten 20000 to 20k and 11500 to 11.5k
      # But guess what? If we do 20000 / 1000.0, it's 20.0k,
      # and I really want to just display 20k. Well shit.
      if raid.health > 1000 && raid.health % 1000 == 0
        health = (raid.health / 1000).to_s + 'k'
      elsif raid.health > 1000
        health = (raid.health / 1000.0).to_s + 'k'
      else
        health = raid.health.to_s
      end

      str = "#{initiator}'s #{raid.name}: "
      str << "#{members}/#{raid.capacity}, "
      str << '%d/%s (%d%%), ' % [health_left, health, health_p]

      if time_left > 0
        time_p = 100.0 * time_left.to_f / raid.seconds.to_f
        time_p = time_p.round
        a, _, b = Tyrant::Time::format_time(time_left).rpartition(':')
        time_fmt = a.empty? ? b : a
        str << '%s/%d hours (%d%%)' % [time_fmt, raid.hours, time_p]
      else
        str << "Ended #{Tyrant::Time::format_time_days(-time_left)} ago"
      end
      return str
    end
    return "#{initiator}'s unknown raid: #{members}/??, " +
      "#{health_left} HP, #{time_fmt} left"
  end

  def self.raid_key(json); return 0; end
end
