require 'lispobjects.rb'
require 'lispeval.rb'

$macro_characters = {}
$macro_characters_nonterm = {}
$macro_dispatch_characters = []
$macro_dispatch_characters_nonterm = {}
$macro_dispatch_character_combos = {}

def read(str=$stdin)
  true while ($_=str.read(1)) =~ /\s/
  if $macro_characters.has_key? $_
    $macro_characters[$_].apply(str, $_)
  elsif $macro_dispatch_characters.include? $_
    $macro_dispatch_character_combos[[(a=$_), (b=str.read(1))]
      ].apply(str, a, b)
  else
    read_primitive(str, $_)
  end
end

def read_primitive(str, last_char=nil)
  last_char = str.read(1) unless last_char
  case last_char
    when /\d/
      numstr = last_char+basic_read_sym(str)
        
      case numstr
        when /(\d+)\/(\d+)/
          Rational.new($1.to_i, $2.to_i)
        when /\d+\.\d+/
          numstr.to_f
        when /\d+/
          numstr.to_i
      end
    when /\|/
      symstr = str.read(1)
      loop do
        last_char = str.read(1)
        if last_char == "\\"
          symstr << str.read(1)
        elsif last_char == "|"
          return LispSymbol.new(symstr)
        else
          symstr << last_char
        end
      end
    else
      LispSymbol.new(last_char+basic_read_sym(str))
  end
end

def basic_read_sym(str)
  val = ""
  last_char = str.read(1)
  until last_char =~ /\s/ or ($macro_characters.has_key?(last_char) &&
    !$macro_characters_nonterm[last_char]) or 
      ($macro_dispatch_characters.index(last_char) &&
        !$macro_dispatch_characters_nonterm[last_char])
    
    val << last_char
    last_char = str.read(1)
  end
  
  str.ungetc(last_char[0])
  val
end

###To be called after the starting char has been read
def read_delimited_list(str, end_char)
  list =  nil
  
  old_f, old_nt = $macro_characters[end_char],
    $macro_characters_nonterm[end_char]
  
  $macro_characters[end_char] = Function.new(nil, proc{|a,b|
    throw :list_end})
  $macro_characters_nonterm[end_char] = false
  catch(:list_end) do
    loop do
      list = Cons.new(read(str), list)
    end
  end
  
  $macro_characters[end_char] = old_f
  $macro_characters_nonterm[end_char] = old_nt
  list.reverse
end

def read_from_file(file_name)
  str = File.open(file_name) {|f| StringIO.new(f.read)}
  until str.eof
    lisp_eval(read(str))
  end
end

$macro_characters['('] =
  Function.new(nil, proc{|str, ch| read_delimited_list(str, ')')})
$macro_characters_nonterm['('] = false

$macro_characters['"'] = Function.new(nil, proc do |str, ch|
    s = ""
    until (last_char=str.read(1)) == '"'
      s << last_char
    end
    s
  end)
$macro_characters_nonterm['"'] = false