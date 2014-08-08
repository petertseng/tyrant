require 'tyrant'
require 'tyrant/time'

class Tyrant::Rival
  attr_reader :name, :fp, :repeat, :infamy

  def initialize(name, fp, gain, repeat, infamy)
    @name = name
    @fp = fp
    @base_gain = gain
    @repeat = repeat
    @infamy = infamy
  end

  def gain
    return @repeat ? (@base_gain + 1) / 2 : @base_gain
  end
end

class Tyrant

  def self.rating_change(difference)
    return 10 if difference >= 500
    return 9 if difference >= 300
    return 8 if difference >= 200
    return 7 if difference >= 100
    return 6 if difference >= 34
    return 5 if difference >= -33
    return 4 if difference >= -99
    return 3 if difference >= -199
    return 2 if difference >= -299
    return 1
  end

  def raw_rivals(lower_limit = nil, upper_limit = nil)
    if upper_limit != 0
      param_high = 'rating%5Flow=0'
      param_high << "&rating%5Fhigh=#{upper_limit}" if upper_limit
      json_high = make_request('getFactionRivals', param_high)
    else
      json_high = {'rivals' => []}
    end

    if lower_limit != 0
      param_low = 'rating%5Fhigh=0'
      param_low = "rating%5Flow=#{lower_limit}&#{param_low}" if lower_limit
      json_low = make_request('getFactionRivals', param_low)
    else
      json_low = {'rivals' => []}
    end

    # Remove the duplicates that result from factions with same FP as us.
    return json_high['rivals'] | json_low['rivals']
  end

  def self.decreased_fp(rating_time)
    return rating_time != 0 && ::Time.now.to_i - rating_time < 18 * Time::HOUR
  end

  # Converts rivals JSON into [Tyrant::Rival]
  def self.rivalize(rivals, our_fp = nil)
    return rivals.map { |rival|
      name = rival['name']
      their_fp = rival['rating'].to_i
      rating_time = rival['less_rating_time'].to_i
      infamy = rival['infamy_gain'].to_i
      fp_gain = our_fp ? Tyrant::rating_change(their_fp - our_fp) : nil
      decreased_fp = Tyrant::decreased_fp(rating_time)
      Tyrant::Rival.new(name, their_fp, fp_gain, decreased_fp, infamy)
    }
  end

  # Selects rivals that result in no infamy
  def open_rivals(lower_limit = nil, upper_limit = nil, our_fp = nil)
    rivals = raw_rivals(lower_limit, upper_limit)

    if our_fp.nil?
      info = make_request('getFactionInfo')
      our_fp = info['rating'] ? info['rating'].to_i : nil
    end

    rivals.select! { |rival| rival['infamy_gain'] == 0 }
    return Tyrant.rivalize(rivals, our_fp)
  end

  def self.format_rivals(rivals)
    fps = []
    rivals.each { |rival|
      fps[rival.gain] ||= []
      fps[rival.gain].push(rival)
    }
    return fps.compact.reverse.map { |rs|
      gain = rs[0].gain.to_s + ": "
      gain + rs.map { |r|
        mark = r.repeat ? '*' : ''
        infamy = r.infamy > 0 ? "[+#{r.infamy}]" : ''
        "#{Tyrant::sanitize_string(r.name)}#{mark}#{infamy} (#{r.fp})"
      }.join(', ')
    }.join("\n")
  end
end
