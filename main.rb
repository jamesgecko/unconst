Variable = Struct.new(:name, :content, :type) do
  def definition(indent = 2)
    ' ' * indent + ( type ? "let #{name}: #{type};" : "let #{name};")
  end

  def assignment(indent = 2)
    result = content.map { |line| ' ' * indent + line}
    result[0] = ' ' * indent + "  #{name} = #{result[0].strip}"
    result 
  end
end

Operation = Struct.new(:name, :content) do
  def definition(indent = 2)
    nil
  end

  def assignment(indent = 2)
    content.map { |line| ' ' * indent + line }
  end
end

class Editor
  def initialize(file, path)
    @file = file
    @middle_index = find_lines(file, 'beforeEach(')[0]
    @above_mod = 0
    @below_mod = 0
    @index = 0

    raise "Missing beforeEach block #{path}" unless @middle_index 
  end

  def replace_above(text_obj)
    puts "replacing #{text_obj}"
    puts text_obj.definition.inspect
    @file[@index] = text_obj.definition # Replacement text is always a single line
    lines_deleted = text_obj.content.length - 1
    if lines_deleted > 0
      lines_deleted.times { @file.delete_at(@index + 1) }
      @above_mod -= lines_deleted
    end
  end

  def insert_below(text_obj)
    puts "inserting #{text_obj}"
    puts text_obj.assignment.inspect
    content = text_obj.assignment
    content.each_with_index do |content_line, content_index|
      @file.insert(@middle_index + 1 + @below_mod + @above_mod + content_index, content_line)
    end
    @below_mod += content.length
  end

  def cursor_line
    @index
  end

  def next_line
    @index += 1
  end

  def reached_middle?
    @index >= @middle_index + @above_mod
  end

  def adjusted_line_number(line_number)
    line_number + @above_mod
  end

  def debug
    puts "a#{@above_mod}, m#{@middle_index}, b#{@below_mod}: #{@middle_index + 1 + @below_mod + @above_mod}"
  end

  def debug_file
    puts '---'
    @file.each_with_index do |line, i|
      puts "#{i + 1}\t #{line}"
    end
    puts '---'
  end
end

def main
  STDIN.each_line do |filepath|
    puts '--- ' + filepath
    path = Dir.pwd + '/' + filepath.strip
    File.open(path) do |f|
      parse(filepath, f.readlines)
    end
  end
end

def find_lines(array, string, first_i = 0, last_i = nil)
  last_i ||= array.length - 1
  array = array[first_i..last_i]
  results = []
  array.each_with_index do |line, i|
    results << i + first_i if line.include?(string)
  end
  results
end

def replace_def(body, index, new_var)
  new_var.content.length # <------- TODO replace defintion without losing line place.
  # There's a const getting left in the file because we're not using indexes carefully enough.
end

def parse(filepath, spec)
  editor = Editor.new(spec, filepath)
  known_variables = {}

  until editor.reached_middle?
    puts "(#{editor.cursor_line})"
    if spec[editor.cursor_line].include?('const')
      puts "const found: #{spec[editor.cursor_line]}"
      variable = parse_variable(spec, editor.cursor_line)
      known_variables[variable.name] = true
      editor.insert_below(variable)
      editor.replace_above(variable)
    end
    editor.next_line
  end

  # i = 0
  # (0..before_each_i).each do
  #   puts i + from_mod
  #   if consts.map {|line_number| editor.adjusted_line_number(line_number) }.include?(i)
      # puts "const at #{i}", spec[i]
      # variable = parse_variable(spec, i)
      # known_variables[variable.name] = true
      # spec.insert(before_each_i + 1 + to_mod, variable.assignment)

      # spec[i + from_mod] = variable.definition
      # extra_lines_changed = variable.content.length - 1
      # puts "extra changed lines: #{extra_lines_changed}"
      # extra_lines_changed.times { spec.delete_at(i + from_mod + 1) }
      # from_mod -= extra_lines_changed if extra_lines_changed > 0
      # to_mod += variable.content.length
      # puts variable.name
    # elsif known_variables[parse_variable_name(spec[i])]
    #   puts 'ho'
      # name = parse_variable_name(spec[i])
      # puts "known variable #{name}"
      # operation = Operation.new(name, parse_variable_content(spec, i))

      # spec.insert(before_each_i + 1 + before_each_mod, operation.body)
      # extra_lines_changed = operation.content.length - 1
      # extra_lines_changed.times { spec.delete_at(i + mod + 1) }
      # mod -= extra_lines_changed if extra_lines_changed > 0
      # before_each_mod += operation.content.length
  #   elsif parse_variable_name(spec[i]) == 'beforeEach'
  #     break
  #   end
  #   i += 1
  # end
  puts spec
end

def parse_variable_name(line)
  name = line.strip.match(/^(.*?)(?=[.=(]+)/)
  name ? name[1] : nil
end

def parse_variable(array, starting_index)
  line = array[starting_index]
  name = line.match(/(?<=const )(.*?)(?=[ :=]+)/)[1]
  type_match = line.match(/(?<=const #{name}:)(.*?)(?=[=]+)/)
  type = type_match[1].strip if type_match
  content = parse_content(array, starting_index)
  Variable.new(name, content, type)
end

def parse_content(array, starting_index)
  result = []
  first_content_index = array[starting_index].index('=') + 1
  first_line = array[starting_index][first_content_index..-1]
  result << first_line
  return result if first_line.strip[-1] == ';'
  index_offset = starting_index + 1
  array[index_offset..-1].each_with_index do |line, index|
    result << line
    return result if line.strip[-1] == ';'
  end
  raise 'Runaway parser'
end

def parse_variable_content(array, starting_index)
  result = []
  first_line = array[starting_index]
  result << first_line
  return result if first_line.strip[-1] == ';'
  index_offset = starting_index + 1
  array[index_offset..-1].each_with_index do |line, index|
    result << line
    return result if line.strip[-1] == ';'
  end
  raise 'Runaway parser'
end

# def parse_content_stack(array, starting_index)
#   stack = []
#   stack_vars = {
#     '(' => ')',
#     '{' => '}',
#     '[' => ']'
#   }
#   first_content_index = array[starting_index].index('=') + 1
#   line = array[starting_index..-1]
#   index = starting_index
#   result = []

#   (starting_index..array.length - 1).each do |i|
#     line.each do |char|
#       if stack_vars[char]
#         stack << stack_vars[char] 
#       elsif char == stack[-1]
#         stack.pop
#       end
#     end
#     result << line
#     return result if stack.count == 0 && line.strip[-1] == ';'
#     line = array[i]
#   end
# end

main()

# Find consts
# Locate entire const definition
# Add const assignment entries into beforeEach at correct indention
# Add let defines in the original location
# Find anything outside beforeEach with the defined names
# Move it into beforeEach, too, preserving it's location in relation to assignments
