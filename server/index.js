var express = require('express')
var bodyParser = require('body-parser')
var request = require('request')

var credentials = require("./credentials.json")

var app = express()

// parse application/json
app.use(bodyParser.json())


app.get('/', function(req, res){
  console.log('/');
  res.send('hello');
});

app.post('/pay', function(req, res){
  var payment = req.body;
  console.log('Payment', payment);

  authoriseApplePay(payment, function(json, error){
    if (json && json.pspReference && json.resultCode == 'Authorised') {
      return res.json(json);
    }
    res.status(500).end();

  })
})
/*
PKShippingMethod *item = [PKShippingMethod summaryItemWithLabel:d[@"label"] amount:[NSDecimalNumber decimalNumberWithString:d[@"amount"]]];
item.detail = d[@"detail"];
item.identifier = d[@"identifier"];
*/

app.post('/shipping', function(req, res){
  var record = req.body;
  console.log('Shipping to', record);

  var sm_l_nd = { identifier: 'sm_l_nd', label: 'Next day', amount: '0.0', detail: 'Next day delivery' }
  var sm_l_ex = { identifier: 'sm_l_ex', label: 'Express', amount: '3.0', detail: 'This day express delivery' }
  var sm_i_nd = { identifier: 'sm_i_nd', label: 'Int Next day', amount: '6.0', detail: 'International Next day delivery' }
  var sm_i_ex = { identifier: 'sm_i_ex', label: 'Int Express', amount: '20.0', detail: 'International This day express delivery' }

  if (record.countryCode == 'GB') {
    res.json([sm_l_nd, sm_l_ex]);
  } else if (record.countryCode == 'US') {
    res.json([sm_i_nd, sm_i_ex]);
  } else {
    console.log('Shipping not supported');
    res.status(400).end();
  }


})


app.listen(8080);


function authoriseApplePay(payment, callback){

  var token = payment.paymentData;

  if (!token || token.length == 0) {
    console.log('No token');
    //return callback(null, null);
  }

  var amount_minor_units = String((payment.amount * 100).toFixed(0));

  var data = {
    additionalData: {
      'payment.token': token
    },
    amount: {
      currency: payment.currencyCode,
      value: amount_minor_units
    },
    merchantAccount: 'TestMerchantAP',
    reference: payment.merchantReference
  }

  var test = false

  if (token && token.length) {
    var buf = new Buffer(token, 'base64');
    var paymentToken = JSON.parse(buf.toString());
    if (paymentToken.version == 'Adyen_Test') {
      test = true;
    }
  }


  var host = (test) ? 'pal-test.adyen.com' : 'pal-live.adyen.com'
  var env = (test) ? 'test' : 'live';
  var auth = {user: credentials[env].user, pass: credentials[env].pass}


  var url = 'https://' + host + '/pal/servlet/Payment/V12/authorise'

  console.log('Sending to Adyen', url, data);

  request.post({url: url, auth: auth, json: data}, function (error, response, body){
    console.log('Adyen resp', response.statusCode, body, error);
    if (!error && response.statusCode == 200) {
      callback(body, null);
    } else {
      callback(null, error);
    }
  });
}
