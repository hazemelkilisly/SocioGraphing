# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

## Users:
# tawfik = User.create(name: "Hazem Tawfik",email: "hazem@gmail.com", password:"12345678")
# hegazy = User.create(name: "Ahmed Hegazy",email: "hegazy@gmail.com", password:"12345678")
# talaat = User.create(name: "Amr Talaat",email: "amr@gmail.com", password:"12345678")
# abbas = User.create(name: "Hazem Abbas",email: "abbas@gmail.com", password:"12345678")
# tarek = User.create(name: "Mohamed Tarek",email: "tarek@gmail.com", password:"12345678")
# ayman = User.create(name: "Mohamed Ayman",email: "ayman@gmail.com", password:"12345678")
# ## work circle
# meky = User.create(name: "Omar Mekky",email: "omar@gmail.com", password:"12345678")
# diaa = User.create(name: "Karim Diaa",email: "diaa@gmail.com", password:"12345678")
# maria = User.create(name: "Maria Sancheiz",email: "maria@gmail.com", password:"12345678")
# #####

# tawfik.track(hegazy)
# tawfik.track(talaat)
# tawfik.track(abbas)
# tawfik.track(diaa)
# # tawfik.track(tarek)
# tawfik.track(ayman)
# ##
# hegazy.track(tawfik)
# hegazy.track(talaat)
# hegazy.track(ayman)
# ##
# talaat.track(tawfik)
# talaat.track(abbas)
# ##
# abbas.track(talaat)
# ##
# # tarek.track(tawfik)
# ##
# ayman.track(tawfik)
# ayman.track(hegazy)
# ##
# diaa.track(meky)
# diaa.track(tawfik)
# ##
# meky.track(diaa)
# meky.track(tarek)
# ##
# tarek.track(meky)
# tarek.track(maria)
# maria.track(tarek)
#####