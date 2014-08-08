class Tyrant
  def player_info_by_id(player_id); return {}; end

  def player_info_by_name(player_name)
    id = Tyrant::id_of_name(player_name)
    return nil unless id
    return player_info_by_id(id)
  end

  def self.id_of_name(player_name); return 0; end
  def self.name_of_id(player_id); return ''; end
  def self.name_of_fbid(player_id); return ''; end
end
