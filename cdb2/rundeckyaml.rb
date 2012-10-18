class RundeckYaml

  def to_rundeckyaml( config )
    "Ausgabe im rundeck Format"
    rundeckyaml = "---\n"
    config.each_pair { |host,hostvalue|
      rundeckyaml += host.split('.')[0..2].join(".") + ":\n"
      rundeckyaml += "  description: " + hostvalue['team'].to_s + "\n"
      rundeckyaml += "  hostname: " + host + "\n"
      rundeckyaml += "  nodename: " + host + "\n"
      rundeckyaml += "  username: " + hostvalue['osadmin'].to_s + "\n"
      rundeckyaml += "  tags: "
      firstround = true
      hostvalue['role'].each { |role|
        if firstround
          rundeckyaml += role
        else
          rundeckyaml += "," + role
        end
        firstround = false
      }
      rundeckyaml += "\n" 
    }
    rundeckyaml
  end

end

