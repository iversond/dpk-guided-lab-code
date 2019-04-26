Facter.add(:app) do
    setcode do
      app = ENV["NODENAME"][2..3]
      app.downcase
    end
  end
  
  Facter.add(:hostnum) do
    setcode do
      hostnum = ENV["NODENAME"][7..9]
      hostnum
    end
  end
  
  Facter.add(:region) do
    setcode do
      hostname = ENV["NODENAME"][4..6]
      if hostname.downcase.match(/tst/)
        region = "TEST"
      end
      if hostname.downcase.match(/dev/)
        region = "DEVELOPMENT"
      end
      if hostname.downcase.match(/prd/)
        region = "PRODUCTION"
      end
      region
    end
  end