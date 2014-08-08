class Tyrant
  TYRANT_SANITIZE_SUBS = {
    "\t" => '\t',
    "\r" => '\r',
    "\n" => '\n',
    ' ' => ' ',
  }
  TYRANT_SANITIZE_SUBS.default = '?'

  def self.sanitize_string(s)
    return s.gsub(/\s/, TYRANT_SANITIZE_SUBS)
  end

  def self.sanitize_or_default(str, default)
    return default unless str
    return Tyrant::sanitize_string(str)
  end
end
