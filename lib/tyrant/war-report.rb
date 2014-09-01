require 'tyrant'
require 'tyrant/faction'
require 'tyrant/player'
require 'tyrant/war'

class Tyrant::Player
  attr_reader :id, :name
  attr_reader :dealt, :taken, :attacks
  attr_reader :attack_wins, :attack_losses, :defense_wins, :defense_losses
  attr_reader :wars, :wars_active, :wars_positive, :wars_active_positive
  attr_reader :last_war

  def initialize(id, name)
    @id = id
    @name = name
    @dealt = 0
    @taken = 0
    @attacks = 0
    @attack_wins = 0
    @attack_losses = 0
    @defense_wins = 0
    @defense_losses = 0
    @wars = 0
    @wars_active = 0
    @wars_positive = 0
    @wars_active_positive = 0
    @last_war = nil
  end

  def lookup_name
    @name ||= Tyrant::name_of_id(@id)
  end

  def add_war(rank)
    dealt = rank['points'].to_i
    taken = rank['points_against'].to_i
    attacks = rank['battles_fought'].to_i
    @dealt += dealt
    @taken += taken
    @attacks += attacks
    @attack_wins += rank['wins'].to_i
    @attack_losses += rank['losses'].to_i
    @defense_wins += rank['defense_wins'].to_i
    @defense_losses += rank['defense_losses'].to_i
    @wars += 1
    @wars_positive += 1 if dealt > taken
    @wars_active += 1 if attacks > 0
    @wars_active_positive += 1 if dealt > taken && attacks > 0
    @last_war = rank['faction_war_id'] if attacks > 0 && !@last_war
  end

  def wins
    return attack_wins + defense_wins
  end

  def losses
    return attack_losses + defense_losses
  end

  def attack_battles
    return attack_wins + attack_losses
  end

  def defense_battles
    return defense_wins + defense_losses
  end

  def battles
    return wins + losses
  end

  def net
    return @dealt - @taken
  end

  def points_per_battle
    return self.battles == 0 ? 0 : self.net.to_f / self.battles.to_f
  end

  def winrate
    return self.battles == 0 ? 0 : wins.to_f / self.battles.to_f
  end
end

class Tyrant

  STATS_FMT = []

  STATS_FMT[0] = <<COUNTS
Active players:     Us %<us_players>5d, Them %<them_players>5d
Points per battle:  Us %<us_ppb>5.2f, Them %<them_ppb>5.2f
Our attack win%%:   %<us_attack_wins>5d/%<us_attack_battles>5d = %<us_attack_win_percent>5.2f%%
Their attack win%%: %<them_attack_wins>5d/%<them_attack_battles>5d = %<them_attack_win_percent>5.2f%%
Surrender-o-meter:  Us %<us_io_surrender>5.2f, Them %<them_io_surrender>5.2f
COUNTS

  STATS_FMT[1] = <<COUNTS
-----OVERALL STATS-----
Active players:    Us %<us_players>5d, Them %<them_players>5d
Points per battle: Us %<us_ppb>5.2f, Them %<them_ppb>5.2f
Our attack win%%:   %<us_attack_wins>5d/%<us_attack_battles>5d = %<us_attack_win_percent>5.2f%%
Their attack win%%: %<them_attack_wins>5d/%<them_attack_battles>5d = %<them_attack_win_percent>5.2f%%
-----INACTIVE-ONLY STATS-----
Inactive players:  Us %<us_inactives>5d, Them %<them_inactives>5d
Points per win:    Us %<us_io_ppw>5.2f, Them %<them_io_ppw>5.2f
Points per battle: Us %<us_io_ppb>5.2f, Them %<them_io_ppb>5.2f
Surrender-o-meter: Us %<us_io_surrender>5.2f, Them %<them_io_surrender>5.2f
COUNTS

  # Returns Hash[id->Tyrant::Player] with stats for the wars given in `war_ids`.
  # Will include both factions if who == :both,
  # only this player's faction if who == :us,
  # and only this player's opponent if who == :them.
  #
  # If a block is given, each rank JSON is passed to the block.
  # Stats are not counted if the block returns false or nil.
  def war_reports(war_ids, who = :us, cache: true)
    raise 'No cache for large array?!' if war_ids.count > 1 && !cache

    members = faction_members
    players = Hash.new { |h, k|
      h[k] = Player.new(k, members[k] && members[k]['name'])
    }

    war_ids.each { |war_id|
      war_rankings(war_id, who, cache: cache).each { |k, v|
        v.each { |rank|
          next if block_given? && !(yield rank)

          player = players[rank['user_id']]
          player.add_war(rank)
        }
      }
    }

    return players
  end

  def self.sum_by_key(array, method)
    return array.map { |e| e.send(method) }.inject(0, :+)
  end

  # Intended for internal use. Calculates stats for one side of the war.
  def self.war_counts_one(us, them, prefix)
    us_players, us_inactives = us.partition { |p| p.attacks > 0 }
    _, them_inactives = them.partition { |p| p.attacks > 0 }

    us_points = sum_by_key(us_players, :dealt)

    us_attack_wins = sum_by_key(us, :attack_wins)
    us_attack_battles = sum_by_key(us, :attack_battles)
    us_attack_win_percent = us_attack_wins.to_f / us_attack_battles * 100

    them_inactive_wins = sum_by_key(them_inactives, :wins)
    them_inactive_losses = sum_by_key(them_inactives, :losses)
    them_inactive_battles = them_inactive_wins + them_inactive_losses

    them_inactive_dealt = sum_by_key(them_inactives, :dealt)
    them_inactive_taken = sum_by_key(them_inactives, :taken)

    return {
      :"#{prefix}_players" => us_players.size,
      :"#{prefix}_inactives" => us_inactives.size,
      :"#{prefix}_dealt" => sum_by_key(us, :dealt),
      :"#{prefix}_taken" => sum_by_key(us, :taken),
      :"#{prefix}_ppb" => us_points.to_f / us_attack_battles,
      :"#{prefix}_attack_wins" => us_attack_wins,
      :"#{prefix}_attack_battles" => us_attack_battles,
      :"#{prefix}_attack_win_percent" => us_attack_win_percent,
      :"#{prefix}_io_ppw" => them_inactive_taken.to_f / them_inactive_losses,
      :"#{prefix}_io_ppb" => them_inactive_taken.to_f / them_inactive_battles,
      :"#{prefix}_io_surrender" => them_inactive_dealt.to_f / them_inactive_wins,
    }
  end

  # Calculates stats for the war.
  # `us` and `them` should be [Tyrant::Player],
  # containing players from the two opposing factions.
  # Returns Hash[Symbol->number]
  def self.war_counts(us, them)
    us_stats = war_counts_one(us, them, 'us')
    them_stats = war_counts_one(them, us, 'them')
    return us_stats.merge(them_stats)
  end
end
