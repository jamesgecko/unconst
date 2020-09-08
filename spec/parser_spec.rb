require_relative '../main.rb'
require 'test/unit'

class TestParser < Test::Unit::TestCase
  def test_moves_const_with_definition
    before = [
      "  const foo = 'foo';\n",
      "  beforeEach(() => {\n",
      "  });\n"
    ]
    after = [
      "  let foo;\n",
      "  beforeEach(() => {\n",
      "    foo = 'foo';\n",
      "  });\n"
    ]
    assert_equal(after, parse('test', before))
  end

  def test_moves_const_with_type_definition
    before = [
      "  const foo: string = 'foo';\n",
      "  beforeEach(() => {\n",
      "  });\n"
    ]
    after = [
      "  let foo: string;\n",
      "  beforeEach(() => {\n",
      "    foo = 'foo';\n",
      "  });\n"
    ]
    assert_equal(after, parse('test', before))
  end

  def test_moves_const_with_multiple_line_definition
    before = [
      "  const foo = [\n",
      "    'foo'\n",
      "  ];\n",
      "  beforeEach(() => {\n",
      "  });\n"
    ]
    after = [
      "  let foo;\n",
      "  beforeEach(() => {\n",
      "    foo = [\n",
      "      'foo'\n",
      "    ];\n",
      "  });\n"
    ]
    assert_equal(after, parse('test', before))
  end

  def test_moves_spies
    before = [
      "  const fooService = jasmine.createSpyObj('FooService', ['bar']);\n",
      "  fooService.bar.and.returnValue(of({ 'bar' }));\n",
      "  beforeEach(() => {\n",
      "  });\n"
    ]
    after = [
      "  let fooService;\n",
      "  beforeEach(() => {\n",
      "    fooService = jasmine.createSpyObj('FooService', ['bar']);\n",
      "    fooService.bar.and.returnValue(of({ 'bar' }));\n",
      "  });\n"
    ]
    assert_equal(after, parse('test', before))
  end

  def test_moves_multi_line_spies
    before = [
      "  const fooService = jasmine.createSpyObj('FooService', ['bar']);\n",
      "  fooService.bar.and.returnValue(\n",
      "    of({ 'bar' }));\n",
      "  beforeEach(() => {\n",
      "  });\n"
    ]
    after = [
      "  let fooService;\n",
      "  beforeEach(() => {\n",
      "    fooService = jasmine.createSpyObj('FooService', ['bar']);\n",
      "    fooService.bar.and.returnValue(\n",
      "      of({ 'bar' }));\n",
      "  });\n"
    ]
    assert_equal(after, parse('test', before))
  end

  def test_moves_let_spies
    before = [
      "  let foo;\n",
      "  foo = 'foo';\n",
      "  beforeEach(() => {\n",
      "  });\n"
    ]
    after = [
      "  let foo;\n",
      "  beforeEach(() => {\n",
      "    foo = 'foo';\n",
      "  });\n"
    ]
    assert_equal(after, parse('test', before))
  end

  def test_adds_missing_before_each_block
    before = [
      "describe('Foo', () => \n",
      "  const foo = 'foo';\n",
      "  describe(() => {\n"
    ]
    after = [
      "describe('Foo', () => \n",
      "  let foo;\n",
      "  beforeEach(() => {\n",
      "    foo = 'foo';\n",
      "  });\n",
      "\n",
      "  describe(() => {\n"
    ]
    assert_equal(after, parse('test', before))
  end

  def test_adds_missing_before_each_block_when_it_encountered
    before = [
      "describe('Foo', () => \n",
      "  const foo = 'foo';\n",
      "  it('tests a thing', () => {\n"
    ]
    after = [
      "describe('Foo', () => \n",
      "  let foo;\n",
      "  beforeEach(() => {\n",
      "    foo = 'foo';\n",
      "  });\n",
      "\n",
      "  it('tests a thing', () => {\n"
    ]
    assert_equal(after, parse('test', before))
  end

  def test_moves_object_containing_function
    before = [
      "  const mockLongRunningTask = {\n",
      "    checkTask() {\n",
      "      return of(longRunningTaskData);\n",
      "    }\n",
      "  };\n",
      "  beforeEach(() => {\n",
      "  });\n"
    ]
    after = [
      "  let mockLongRunningTask;\n",
      "  beforeEach(() => {\n",
      "    mockLongRunningTask = {\n",
      "      checkTask() {\n",
      "        return of(longRunningTaskData);\n",
      "      }\n",
      "    };\n",
      "  });\n"
    ]
    assert_equal(after, parse('test', before))
  end
end
