# Introduction
Fera.js is a JavaScript SDK to gather and display customer reviews, photos and videos on your site.

# Development
### Requirements
- NPM and Yarn
- Ruby 2.7.6 and bundler gem installed

### Setup
Assuming your bundler and yarn installed:
```bash
yarn install
bundle install
```

### Dev server
Run the dev server with `yarn dev`.

This command will:
1. Watch for CSS/JS changes and compile them into dist/
2. Start a simple static file web server at port 3007.

You can then test your changes at http://localhost:3007.

### Lint
Run `yarn lint` to lint your code.

To auto-fix violations simply run `yarn lint -a` (recommended before each commit).

##### Linters used
- Rubocop - for tests

# Build
Run `yarn build` to build the project into dist/.

# Tests
Run `yarn test` to run the tests.

To run tests and see the browser to debug things you can run `yarn test:debug`.

### How testing works
We use capybara and rspec for testing. 

It runs a example web server using Thin that serves the files in the examples/ folder.
