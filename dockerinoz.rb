#!/usr/bin/ruby
# encoding: utf-8
# ###
# PoC code by Richard Sammet
# ###

require "json/add/regexp"

DEBUG=false

# rules are defined as ruby objects (serialized in JSON - check rules.json). the name of the rule is the highest level key.
# the value of that key is another object which consists of key => value pairs.
# the keys are
# :regex  => the regular expression used to extract data of interest from the file
# :check  => an array of two regular expressions. the first one is always applied to the first match of :regex
#            the second one is applied to any further matches of :regex
# :cond   => the conditions for the two :check regular expressions. is the rule going to trigger when they match or not
# :exists => can have three different values [bie|bne|nop]; bie = break if exists; bne = break not exists; nop = no operation
#            :exists will cause the rule processing for this rule to stop if the :regex has a match and bie is set OR
#            if it has no match and bne is set; reporting the desc
# :ctx    => is the rule applied to the full file or just line by line
# :comnt  => should the rule be applied to comments as well? set to true, if not, false
# :desc   => the description of the rule. what does it mean when it triggers
# :level  => an estimation of the risk when the rule hits

@dojson=false
@dockerfile=""

if not ARGV[0] then
  print "USAGE: SCRIPT [--json] DOCKERFILE\n"
  exit
end

# run with --json as first parameter to get json output
if ARGV[0] == "--json" and ARGV[1].length > 0 then
  @dojson=true
  @dockerfile=ARGV[1]
  @report={ :Dockerinoz_Report => { :dockerfile => @dockerfile.to_s, :results => [] } }
else
  @dockerfile=ARGV[0]
end

def reporter(msg)
  if not @dojson then
    print "#{msg[0]}: #{msg[1]}"
    if msg[2].length > 0 then
      print " #{msg[2]}\n"
    else
      print "\n"
    end
  else
    t = {}
    if msg[2].length > 0 then
      t = { :serverity => msg[0].to_s, :description => msg[1].to_s, :data => msg[2].to_s }
    else
      t = { :serverity => msg[0].to_s, :description => msg[1].to_s }
    end
    @report[:Dockerinoz_Report][:results].push( t )
  end
end


rules = JSON.parse(File.read('rules.json'))

c = File.open("#{@dockerfile}").read

# some normalization. we remove "broken up" lines/instructions and make them like each other again ;)
# FIXME: it would be better to break up chained instructions and give them their own, full,
# lines (with their own RUN, ...). that'd make the analysis more reliable and easier!
c.gsub!(/\\\n/, '')

# this is a lazy catch-all handler...
begin

rules.each do |rk, rv|
  next if rv['ctx'] == "line"
  c.force_encoding("UTF-8")
  t = c.scan(rv['regex']['s'])
  print "DEBUG: using regex: #{rv['regex']}  -- of rule: #{rk}  --  and t.length: #{t.length}\n" if DEBUG == true
  print "DEBUG: rv['exists'].to_str: #{rv['exists'].to_str}\n" if DEBUG == true
  if (rv['exists'].to_str == "bne" and t.length == 0) or (rv['exists'].to_str == "bie" and t.length > 0) then
    reporter([rv['level'], rv['desc'], ""])
    next
  else
 
  check = false
  t.each do |tt|
    print "DEBUG: tt[0]=#{tt[0].to_s}\n" if tt[0].to_s.length > 0 if DEBUG == true
    if (rv['check'][0]['s'].match(tt[0].to_s).to_s.length > 0) == rv['cond'][0] then
      check = true
      for i in 1..(tt.length - 1) do 
        tt[i].tr!("\n", " ")
        print "DEBUG: tt[i]=#{tt[i]}\n" if DEBUG == true
        if (rv['check'][1]['s'].match(tt[i]).to_s.length == 0) == rv['cond'][1] then
          check = true
        end
      end
      if check == true
        next
      end
      reporter([rv['level'] ,rv['desc'] ,tt])
    end
  end

  end
end

c.split("\n").each do |l|
  rules.each do |rk, rv|
  next if rv['ctx'] == "file"
  (print "DEBUG: detected commented line and rule should not be applied to comments, skipping.\n#{l}\n" if DEBUG==true ; next) if rv['comnt'] == false and /^\s*#+/.match(l)
  l.force_encoding("UTF-8")
  check = true
    # t should always be an array with two or more entries
    rx = Regexp.new(rv['regex']['s'].to_s)
    t = l.scan(rx).flatten
    print "DEBUG: using regex: #{rv['regex']}  -- of rule: #{rk}  --  and t.length: #{t.length}\n" if DEBUG == true
    print "DEBUG: rv['exists'].to_str: #{rv['exists'].to_str}\n" if DEBUG == true
    print "DEBUG: t[0]=#{t[0]}\n" if t[0].to_s.length > 0 if DEBUG == true
    print "DEBUG:  #{rv['check'][0]['s'].match(t[0].to_s).to_s}\n" if DEBUG == true
    rx = Regexp.new(rv['check'][0]['s'].to_s)
    if (rx.match(t[0].to_s).to_s.length > 0) == rv['cond'][0] then
      #check = true
      check = rv['cond'][0]
      for i in 1..(t.length - 1) do 
        print "DEBUG: t[i]=#{t[i]}\n" if DEBUG == true
        rx = Regexp.new(rv['check'][1]['s'].to_s)
        if (rx.match(t[i]).to_s.length == 0) == rv['cond'][1] then
          #check = true
          check = rv['cond'][1]
          reporter([rv['level'], rv['desc'], t])
          next
        end
      end
      if check == true
        next
      end
    end
  end
end

rescue Exception => e
  print "EXCEPTION PARSING #{ARGV[0]} :\n"
  puts e.message  
  puts e.backtrace.inspect  
end

puts @report.to_json if @dojson
