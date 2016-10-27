require 'ostruct'

class Hash
  def self.to_ostructs(obj, memo={})
    return obj unless obj.is_a? Hash
    os = memo[obj] = OpenStruct.new
    obj.each { |k,v| os.send("#{k}=", memo[v] || to_ostructs(v, memo)) }
    os
  end
end


class ConfigReader
  def initialize
    @config = Hash.to_ostructs(YAML.load_file(File.join(Dir.pwd, 'config.yml')))
  end

  def get_config
    @config
  end
end