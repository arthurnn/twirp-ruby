module Twirp

  # Register a new service
  def self.[]=(key, value)
    @@services ||= {}
    @@services[key] = value
  end

  # Access a registered service
  def self.[](key)
    return nil unless @@services
    @@services[key]
  end

  # Clear all registered services
  def self.clear_services!
    @@services = nil
  end

end
