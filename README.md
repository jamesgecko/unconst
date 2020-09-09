# Unconst

This script fixes an issue in Jasmine 2.x test suites. When test objects are
declared as constants outside of the initial beforeEach block, the objects can
be shared between specs. This is problematic because these constant objects are
mutable and changes persist between specs. We can end up with tests that only
pass if run in a certain order. This script edits a test suite to move objects
inside beforeEach blocks. A common failure works like this:

```typescript
describe('MyClass', () => {
  const fooMock = jasmine.createSpyObj(['getFoo']);

  it("does something", () => {
    fooMock.getFoo.and.returnValue(of({ sharedObjects: 'yes' }));
    // Use fooMock
  });

  it("does something else", () => {
    // This test fails if it's run before "does something" because it
    // expects fooMock.getFoo to return { sharedObjects: 'yes' }
  });
});
```

This script will make the issue obvious by doing this:

```typescript
describe('MyClass', () => {
  let fooMock;

  beforeEach(() => {
    fooMock = jasmine.createSpyObj(['getFoo']);
  });

  it("does something", () => {
    fooMock.getFoo.and.returnValue(of({ sharedObjects: 'yes' }));
    // Use fooMock
  });

  it("does something else", () => {
    // This test now fails all the time until you define fooMock.getFoo
  });
});
```

## Usage

Single file usage:

```shell
$ echo 'path/to/my/spec/test.spec.ts' | ruby ~/unconst/main.rb
```

Bulk file usage with [The Silver Seacher](https://github.com/ggreer/the_silver_searcher):

```shell
$ ag -l 'const.*mock' --file-search-regex spec.ts | ruby ~/unconst/main.rb
```

## Disclaimer

It goes without saying that you should only run this script on a fresh branch of
a source repo. It WILL rewrite your code and it is not good at parsing. Keep a
backup and manually review the output!

I accept no libaility for trashing your source code. 🙂

Please also note that this was never intended to see the light of day; it started
as a glorified editor script and does not meet my high personal standards for
code quality. I'll try to clean it up a bit soon.
