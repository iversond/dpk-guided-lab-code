Facter.add(:app) do
    setcode do
      app = Facter.value(:hostname)[2..3]
      app.downcase
    end
  end
  
  Facter.add(:hostnum) do
    setcode do
      hostnum = Facter.value(:hostname)[7..9]
      hostnum
    end
  end
  
  Facter.add(:region) do
    setcode do
      hostname = Facter.value(:hostname)[4..6]
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