require 'configatron'

configatron.configure_from_hash(
    lending_club:
    {
            authorization: '',  #Lending Club API key
            account: 123456789,       # Lending Club account number
            portfolio_id: 123456789,         # id of the portfolio to add purchased notes to
            investment_amount: 25,          # amount to invest per loan ($25 minimum)
            max_checks: 35,     # number of times to check for newly released loans

            api_version: 'v1',
            base_url: 'https://api.lendingclub.com/api/investor',
            content_type: 'application/json'
    },
    default_predictor:
    {
            base_url: 'http://###.###.###.###',
            content_type: 'application/json',
            port: '####',
            max_default_prob: 0.01,
            test_file: 'Test/loanlist-example.json'
    },
    push_bullet:
    {
            enabled: false, # true/false
            api_key: '',
            device_id: ''
    },
    logging:
    {
            #path to store log files
            order_response_log: '/var/log/lending_club_autoinvestor/lc_order_response.log',
            order_list_log: '/var/log/lending_club_autoinvestor/lc_order_list.log',
            error_list_log: '/var/log/lending_club_autoinvestor/lc_error_list.log'
    },
    testing_files:
    {
            #alternate between the two purchase_response values to alternate test types
            purchase_response: 'Test/MixedPurchaseResponse.rb',
            #purchase_response: 'Test/FailedPurchaseResponse.rb',
            available_loans: 'Test/AvailableLoans.rb',
            owned_loans:  'Test/OwnedLoans.rb'
    }
)