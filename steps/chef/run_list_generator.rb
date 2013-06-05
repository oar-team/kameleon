#!/usr/bin/ruby 

recipies=""

ARGV.each do|a|
 recipies+="\"recipe[#{a}]\""
 recipies+=" , " unless a == ARGV.last
end

File.open("node.json","w") do |file|

  file.write("{\n")
  file.write("\"run_list\": [ #{recipies} ] \n")
  file.write("}\n")

end
