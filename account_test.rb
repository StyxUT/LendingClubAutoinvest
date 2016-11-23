require 'minitest/autorun'
require_relative '../lib/autoinvestor/account.rb'

def square_root(value)
	Math.sqrt(value)
end

def test_two
	1 + 1
end

class AccountTest < Minitest::Test
  
  def test_with_a_perfect_square
    assert_equal 3, square_root(9)
  end

  def test_two_equals_two
  	assert_equal 3, test_two
  end

end