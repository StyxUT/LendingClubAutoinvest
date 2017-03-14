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
        max_default_prob: 0.01,  # maximum acceptable probability of default.  Note:  0.01 is 1%
        test_file: 'test_files/loanlist_example.json'
    },
    push_bullet:
    {
        enabled: false, # true/false
        api_key: '',
        device_id: ''
    },
    logging:
    {
        #loan purchase
        order_response_log: '/var/log/lending_club_autoinvestor/lc_order_response.log',
        order_list_log: '/var/log/lending_club_autoinvestor/lc_order_list.log',
        error_list_log: '/var/log/lending_club_autoinvestor/lc_error_list.log',

        #folio
        sell_order_response_log: '/var/log/lending_club_autoinvestor/lc_sell_order_response.log',
        sell_order_list_log: '/var/log/lending_club_autoinvestor/lc_sell_order_list.log',
        sell_error_list_log: '/var/log/lending_club_autoinvestor/lc_sell_error_list.log'
    },
    test_files:
    {
        #alternate between the two purchase_response values to alternate test types
        purchase_response: 'test/test_files/mixed_purchase_response.json',
        #purchase_response: 'test/test_files/failed_purchase_response.rb',
        available_loans: 'test/test_files/available_loans.json',
        owned_loans:  'test/test_files/owned_loans.json',
        owned_loans_detail:  'test/test_files/owned_loans_detail.json',

        folio_sell_order_response: 'test/test_files/folio_sell_order_response.json',
        errored_folio_sell_order_response: 'test/test_files/errored_folio_sell_order_response.json'
    },
    folio:
    {
        #https://api.lendingclub.com/api/investor/v1/accounts/<investor id>/trades/sell
        base_url: 'https://api.lendingclub.com/api/investor',
        api_version: 'v1',
        content_type: 'application/json',

        expire_days: 1
    }
)