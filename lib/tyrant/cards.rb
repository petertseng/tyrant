require 'nokogiri'

require 'tyrant'
require 'tyrant/monkey/nokogiri-get-one'

class Tyrant::Card
  attr_reader :id, :name, :attack, :health, :wait, :rarity, :faction, :set
  attr_reader :hash, :set_id, :skills, :type, :summoned_by

  RARITIES = [nil, 'Common', 'Uncommon', 'Rare', 'Legendary']
  FACTIONS = [
    nil,
    'Imperial',
    'BOSS',
    'Bloodthirsty',
    'Xeno',
    'Naval',
    'Manned',
    nil,
    'Righteous',
    'Raider'
  ]
  SETS = {
    1000 => 'Standard',
    1 => 'Enclave',
    2 => 'Nexus',
    3 => 'Blight',
    4 => 'Purity',
    5 => 'Homeworld',
    6 => 'Phobos',
    7 => 'Phobos Aftermath',
    8 => 'Awakening',
    9 => 'Terminus',
    10 => 'Occupation',
    11 => 'Worldship',
    12 => 'Flashpoint',
    5000 => 'Reward',
    5001 => 'Promotional',
    5002 => 'Upgraded',
    9000 => 'Exclusive',
    9999 => 'Waitlisted',
  }

  def initialize(xml)
    @id = xml.get_one('id').to_i
    @hash = (@id >= 4000 ? '-' : '') + Tyrant::Cards::hash_of_id(@id % 4000)
    @name = xml.get_one('name')
    @attack = xml.get_one('attack').to_i
    @health = xml.get_one('health').to_i
    @wait = xml.get_one('cost').to_i
    rarity_id = xml.get_one('rarity').to_i
    unique = !xml.get_one('unique').nil?
    @rarity = RARITIES[rarity_id]
    @rarity = 'Unique ' + @rarity if unique
    faction_id = xml.get_one('type').to_i
    @faction = FACTIONS[faction_id]
    @set_id = xml.get_one('set')
    @set_id = @set_id.to_i unless @set_id.nil?
    @name << '+' if @set_id == 5002
    @set = @set_id ? SETS[@set_id] : '(no set)'
    @skills = xml.xpath('skill').map { |skill|
      Tyrant::Card.parse_skill(skill)
    }.join(', ')
    @skills = 'No skills' if @skills.empty?

    if @id >= 5000
      raise 'Whoa ID 5000???'
    elsif @id >= 4000
      @type = :assault
    elsif @id >= 3000
      @type = :action
    elsif @id >= 2000
      @type = :structure
    elsif @id >= 1000
      @type = :commander
    else
      @type = :assault
    end
    @summoned_by = []
  end

  def to_s
    s = "#{@name} [#{@id}]: "
    case @type
    when :action
      s << "#{@rarity} Action"
    when :structure
      s << "-/#{@health}/#{@wait} #{@rarity} #{@faction} Structure"
    when :commander
      s << "#{@health}HP #{@rarity} #{@faction} Commander"
    when :assault
      s << "#{@attack}/#{@health}/#{@wait} #{@rarity} #{@faction} Assault"
    else
      raise "Unknown card type #{@type}"
    end
    summoned = ''
    if !summoned_by.empty?
      x = @summoned_by.join(', ')
      summoned = ', Summoned by ' + x
    end
    s << ", #{@skills}#{summoned}, #{@set}"
    return s
  end

  private

  # Parses an XML fragment into a string representation of a skill
  def self.parse_skill(xml)
    s = xml['id'].capitalize
    s << ' All' if xml['all']
    s << ' ' + FACTIONS[xml['y'].to_i] if xml['y']
    s << ' ' + xml['x'] if xml['x']
    xml.attributes.each { |attr, val|
      case attr
      when 'id', 'all', 'x', 'y', 'z' then nil
      when 'attacked' then s << ' on Attacked'
      when 'played' then s << ' on Play'
      when 'died' then s << ' on Death'
      when 'kill' then s << ' on Kill'
      else raise "New attribute #{attr}"
      end
    }
    return s
  end
end

class Tyrant::Cards
  # Parses the XML file named by `filename`
  # returns [Hash[id->Card], Hash[name->Card]]
  def self.parse_cards(filename)
    doc = Nokogiri::XML(File.open(filename, 'r'))
    cards_by_id = {}
    cards_by_name = {}
    summoners = []

    doc.xpath('//unit').each { |unit|
      card = Tyrant::Card.new(unit)
      cards_by_id[card.id] = card
      summoners.push(card) if card.skills.include?('Summon')
      # prevent inaccessible cards from overwriting accessible cards
      name = card.name.downcase
      name[','] = '' if name.include?(',')
      next if card.set_id.nil? && cards_by_name[name]
      cards_by_name[name] = card
    }

    # Eww, second pass over the summoners.
    summon_regex = /Summon (\d+)/
    summoners.each { |unit|
      summon_target = nil
      summon_regex.match(unit.skills) { |match|
        target_id = match[1].to_i
        card = cards_by_id[target_id]
        summon_target = card ? card.name : "<Unknown card #{target_id}>"
        card.summoned_by.push(unit.name) if card
      }
      unit.skills[summon_regex] = "Summon #{summon_target}"
    }

    return cards_by_id, cards_by_name
  end

  # Parses an array into an array of IDs, using Tyrant::Cards::id_of_name.
  # Each entry in `names` can can be a string or array of strings.
  def self.ids_of_names(names, card_map = nil)
    if card_map.nil?
      _, card_map = Tyrant::Cards::parse_cards(Settings::CARDS_XML)
    end

    return names.map { |name_or_array|
      if name_or_array.is_a?(Array)
        name_or_array.map { |name| id_of_name(name, card_map) }
      else
        id_of_name(name_or_array, card_map)
      end
    }
  end

  def self.hash_of_id(id)
    index1 = id / 64
    index2 = id % 64
    BASE64[index1] + BASE64[index2]
  end

  # Unhashes a standard hash
  # Returns: [cards, invalids]
  # cards is an Array where each element is [id, quantity]
  # invalids is a string of invalid hash characters
  def self.unhash(hash)
    deck = []
    invalid = ''
    # prev_index = first base64 character, or nil if none.
    prev_index = nil
    # offset4000 = true to offset next card by 4000.
    offset4000 = false

    hash.each_char { |char|
      if char == OFFSET4000_CHAR
        offset4000 = true
        next
      end

      index = BASE64.index(char)
      if index.nil?
        invalid << char
        next
      end

      if prev_index.nil?
        prev_index = index
        next
      end

      id = prev_index * 64 + index

      if id > 4000 && !offset4000
        if deck[-1]
          # If ID > 4000 without offsetting, then increase quantity of previous.
          deck[-1][1] += id - 4001
        else
          invalid << "leading-#{BASE64[prev_index]}"
          invalid << "leading-#{char}"
        end
      else
        # Otherwise, treat it normally. Offset if necessary.
        id += 4000 if offset4000
        if deck[-1] && deck[-1][0] == id
          # There was a previous card, and it is the same card as this card.
          # Increase the quantity of the previous card!
          deck[-1][1] += 1
        else
          deck.push([id, 1])
        end
      end
      prev_index = nil
      offset4000 = false
    }
    return [deck, invalid]
  end

  private

  ID_REGEX = /.*\[(\d+)\]/
  OFFSET4000_CHAR = '-'
  BASE64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' +
           'abcdefghijklmnopqrstuvwxyz' +
           '0123456789+/'

  # Resolves a single card name into an ID
  # Accepted formats are:
  # - Name of card (case insensitive)
  # - Any string containing an ID in brackets
  def self.id_of_name(name, card_map)
    m = ID_REGEX.match(name)
    return m[1].to_i if m

    raise "#{name} not found" if !card_map.has_key?(name.downcase)
    return card_map[name.downcase].id
  end
end
