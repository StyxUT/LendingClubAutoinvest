# LendingClubAutoinvest
## Requirements
* Ruby 2.3.1
* A web server running [Lending Club Default Predictor](https://github.com/orangganjil/lendingclub-default-predictor)

## Installation
1.  Install Ruby 2.3.1
2.  Clone LendingClubAutoinvest project `git clone ...`
3.  Change to the LendingClubAutoinvest project folder and install bundler gem `gem install bundler`
4.  Install required gems `bundle install`
5.  Customize the values in example_configatron.rb then rename to configatron.rb
6.  **Optionally** for scheduled execution install clockworkd gem `gem install clockworkd`

## Execution
  ### Manual Execution
  From the project folder:

    bunle exec ./lib/autoinvestor.rb
    
  ### Scheduled Execution
  Schedule execution using clockworkd gem E.g.:

    bundle exec clockworkd start --log -c ~/projects/LendingClubAutoinvest/lib/clock.rb

## Running Tests
Tests are written in [MiniTest](https://github.com/seattlerb/minitest).

Run all tests like this:

    rake
    
Run **loan** class tests like this:

    rake test_loans
    
Run **folio** class tests like this:

    rake test_folio

Run **push_bullet** class tests like this:

    rake test_push_bullet
