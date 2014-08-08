# Tyrant object for interfacing with Tyrant's servers
class Tyrant
  # Makes a request to the Tyrant servers.
  # Returns the result as a Ruby Hash or Array.
  def make_request(message, data = ''); return {}; end

  # Makes a cached request to Tyrant, in the following manner:
  # Checks whether cache_path exists in the cache directory.
  # If so, returns the contents of the file designated by cache_path.
  # If not, makes a request to the Tyrant servers,
  # storing the JSON string in the file designated by cache_path.
  # Returns the result as a Ruby Hash or Array.
  def make_cached_request(cache_path, message, data = ''); return {}; end
end
