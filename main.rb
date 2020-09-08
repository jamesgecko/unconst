# This script fixes a very specific issue in Jasmine 2.x test suites. When test
# objects are declared as constants outside of the initial beforeEach block, the
# objects can be shared between specs.  Jasmine 3+ runs specs in a random order,
# exposing issues with this shared state. All global text objects should be
# declared using `let`, then defined in the beforeEach block.
# This script edits a test suite to get rid of all the shared consts.
#
# Eventual usage: 
# $ ag -l 'const.*mock' --file-search-regex spec.ts | ruby ~/unconst/main.rb
#
# Current usage:
# $ echo 'app/javascript/v2/app/core/services/feature-guard/feature-guard.service.spec.ts' | ruby ~/unconst/main.rb

def log(string)
  puts string if false
end

Variable = Struct.new(:name, :content, :type) do
  def definition(indent = 2)
    @definition ||= ' ' * indent + ( type ? "let #{name}: #{type};\n" : "let #{name};\n")
  end

  def assignment(indent = 2)
    result = content.map { |line| ' ' * indent + line}
    result[0] = ' ' * indent + "  #{name} = #{result[0].strip}\n"
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
    @path = path
    @indent = 2
    @file = file
    @middle_index = find_before_each(file, 'beforeEach(')
    @above_mod = 0
    @below_mod = 0
    @index = 0

    raise "Missing beforeEach block #{path}" unless @middle_index 
  end

  def replace_above(text_obj)
    log "replacing #{text_obj}"
    log text_obj.definition.inspect
    if text_obj.definition
      @file[@index] = text_obj.definition # Replacement text is always a single line for now
    else
      @file.delete_at(@index)
      @above_mod -= 1
      @index -= 1
    end

    lines_deleted = text_obj.content.length - 1
    if lines_deleted > 0
      lines_deleted.times { @file.delete_at(@index + 1) }
      @above_mod -= lines_deleted
    end
  end

  def insert_below(text_obj)
    log "inserting #{text_obj}"
    log text_obj.assignment.inspect
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

  def insert_before_each(index)
    @file.insert(index, ' ' * @indent + "beforeEach(() => {\n")
    @file.insert(index + 1, ' ' * @indent + "});\n")
    @file.insert(index + 2, "\n")
  end

  def find_before_each(array, string)
    describeCount = 0
    array.each_with_index do |line, i|
      describeCount += 1 if line.include?('describe(')
      if describeCount > 1 || line.include?('it(')
        insert_before_each(i)
        return i
      end
      return i if line.include?('beforeEach(')
    end
    raise "Missing beforeEach and describe blocks in #{@path}"
  end

  def debug
    log "a#{@above_mod}, m#{@middle_index}, b#{@below_mod}: #{@middle_index + 1 + @below_mod + @above_mod}"
  end

  def debug_file
    log '---'
    @file.each_with_index do |line, i|
      log "#{i + 1}\t #{line}"
    end
    log '---'
  end
end

def main
  STDIN.each_line do |filepath|
    log '--- ' + filepath
    path = Dir.pwd + '/' + filepath.strip
    File.open(path, 'r+') do |f|
      result = parse(filepath, f.readlines)
      f.rewind
      f.truncate(0)
      f.write(*result)
    end
  end
end

def parse(filepath, spec)
  editor = Editor.new(spec, filepath)
  known_variables = {}
  
  until editor.reached_middle?
    log "(#{editor.cursor_line})"
    if spec[editor.cursor_line].include?('const ')
      log "const found: #{spec[editor.cursor_line]}"
      variable = parse_variable_definition(spec, editor.cursor_line)
      known_variables[variable.name] = true
      editor.insert_below(variable)
      editor.replace_above(variable)
    elsif spec[editor.cursor_line].include?('let ')
      name = parse_let_definition(spec, editor.cursor_line)
      known_variables[name] = true
    elsif known_variables[parse_variable_name(spec[editor.cursor_line])]
      name = parse_variable_name(spec[editor.cursor_line])
      log "known variable found: #{name}"
      operation = Operation.new(name, parse_variable_content(spec, editor.cursor_line))
      editor.insert_below(operation)
      editor.replace_above(operation)
    end
    editor.next_line
  end
  spec
end

def parse_variable_name(line)
  name = line.strip.match(/^(.*?)(?=[.=(]+)/)
  name ? name[1].strip : nil
end

def parse_variable_definition(array, starting_index)
  line = array[starting_index]
  name = line.match(/(?<=const )(.*?)(?=[ :=]+)/)[1]
  type_match = line.match(/(?<=const #{name}:)(.*?)(?=[=]+)/)
  type = type_match[1].strip if type_match
  content = parse_content(array, starting_index)
  Variable.new(name, content, type)
end

def parse_let_definition(array, starting_index)
  line = array[starting_index]
  line.match(/(?<=let )(.*?)(?=[ :;]+)/)[1]
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

main() if __FILE__ == $0
