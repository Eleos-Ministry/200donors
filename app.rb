require 'sinatra'
require 'stripe'
require_relative 'database'

Database.initialize


set :publishable_key, ENV['PUBLISHABLE_KEY']
set :secret_key, ENV['SECRET_KEY']
enable :sessions

Stripe.api_key = settings.secret_key

get '/' do
  @donations = Donation.all
  erb :index
end

get '/goal' do
  @done = Donation.all(:paid => 'true')
  @total = 0
  @done.each do |done|
    @total += done.amount
  end
  erb :goal
end

post '/charge' do
  @donation = Donation.get(params[:donation_id])

  customer = Stripe::Customer.create(
    email: params[:email],
    card: params[:token_id]
  )

  begin
    Stripe::Charge.create(
      amount: @donation.amount*100,
      description: "200 Donors",
      currency: 'usd',
      customer: customer.id
    )

    @donation.update(paid: 'true')
    session[:id] = @donation.id
  rescue Stripe::CardError => e
    body = e.json_body
    session[:error] = body[:error][:message]
    halt 500
  end

  halt 200
end

get '/thanks' do
  @error = session[:error]
  if @error
    halt erb(:thanks)
  end

  @donation = Donation.get(session[:id])

  paid_donations = Donation.all(paid: 'true')
  @total = 0
  paid_donations.each do |done|
    @total += done.amount
  end

  erb :thanks
end

__END__

@@ layout
  <!DOCTYPE html>
  <html>
  <head>
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.2.0/css/bootstrap.min.css">
    <link rel='stylesheet' type='text/css' href='css/main.css'/>
    <script src="//ajax.googleapis.com/ajax/libs/jquery/2.1.1/jquery.min.js"></script>
    <script src="https://checkout.stripe.com/checkout.js"></script>
  </head>
  <body>
    <%= yield %>
  </body>
  </html>

@@index
  <div class="container">
    <div class="row lights">
      <div class="col-md-6">
        <h1>Merry Christmas GOAT!</h1>
        <p>The end of the calendar year always brings excitement. Thanksgiving and Christmas are around the corner and that means time with family and friends that we often miss during the year.</p>
        <p>The end of the year also brings planning and looking forward to the next year. At GOAT, that means planning our capacity for the following year. How many kids can we provide summer experiences for? How many new kids will get to join our Adventure Teams? How many kids will we be able to hire this year?</p>
        <p>As we look towards the next year, much of this planning invovles budgeting. Our goal is to serve kids and change their lives in the long-term. To do this, we have to steward our resources well in the short term.</p>
      </div>
      <div class="col-md-6">
        <h3>&nbsp;</h3>
        <p>This is where we need your help! If someone gives each of the values below from $1-200 we will raise just over $20,000 to kickstart our programs for 2015.</p>
        <p>GOAT would never happen without passionate people giving generously to changing lives in Greenville. We're excited to have each of you as a partner in this Christmas season. If you're interested in learning more about GOAT, please visit our website at <a href="http://goattrips.org">www.goattrips.org</a></p>
        <br /><br />Because we value your privacy, all donations are <a href="http://stripe.com"><img src="img/solid@2x.png" width="119" height="26" border="0" /></a>
      </div>
    </div>
  </div>

  <div class="bigbox">
    <% @donations.each do |donation| %>
      <% if donation.paid? %>
      <div class="giftbox complete">
        Amount: $<%= donation.amount %>.00 Complete!
      </div>
      <% else %>
      <div class="giftbox">
        <form action="/charge" method="post">
          <label class="amount">
            
          </label>
          <button type="submit" class="stripe-button-el" style="visibility: visible;"
            data-amount="<%= donation.amount*100 %>" data-id="<%= donation.id %>">
            <span style="display: block; min-height: 30px;">Donate $<%= donation.amount %></span>
          </button>
        </form>
      </div>
      <% end %>
    <% end %>
  </div>


  <div class="container">
    <div class="row footer">
      <div class="col-md-6">
        <p>To learn more about <a href="http://goattrips.org">GOAT</a>, you can visit our website at <a href="http://goattrips.org">goattrips.org</a> or on <a href="http://facebook.com/goattrips">facebook</a>.</p>
        <p>All donations are processed securely by <a href="http://stripe.com">Stripe</a>.</p>
      </div>
    </div>
  </div>

  <script>
    $('.giftbox').on('click', 'button', function(e) {
      e.preventDefault();
      $this = $(this);

      var handler = StripeCheckout.configure({
        key: '<%= settings.publishable_key %>',
        name: "Great Outdoor Adventure Trips",
        image: 'img/160x160.jpg',
        amount: $this.data('amount'),
        closed: function() {
        },
        token: function(token) {
          $.post( "/charge", {
            token_id: token.id,
            donation_id: $this.data('id'),
            email: token.email
          }).done(function() {
            window.location.href = "/thanks";
          }).fail(function() {
            alert( "Sorry! There was an error processing your donation." );
          });
        }
      });

      handler.open();
    });
  </script>

@@thanks
<div id="fb-root"></div>
<script>(function(d, s, id) {
  var js, fjs = d.getElementsByTagName(s)[0];
  if (d.getElementById(id)) return;
  js = d.createElement(s); js.id = id;
  js.src = "//connect.facebook.net/en_US/sdk.js#xfbml=1&version=v2.0";
  fjs.parentNode.insertBefore(js, fjs);
}(document, 'script', 'facebook-jssdk'));</script>
<div class="container">
  <div class="row">
    <div class="col-md-6 col-md-offset-3">
      <% if @error %>
        <h2>Oh no! There was an error.</h2>
        <p><%= @error %></p>
      <% else %>
      <center>  
        <h3>Thanks for being a part of GOAT Christmas!</h3> 
        <h2>You gave <strong>$<%= @donation.amount %></strong>!</h2>
        <p>(that makes the total: <b>$<%= @total %></b> so far)</p>
      </center>
      <p>You'll be receiving an email soon so we can get more details from you to send a tax-reciept and some other goodies!</p>
      <p><p>
        <br />
        <div class="well">
          <p class="gracias">It would mean the world to us if you would share this with your friends! Tweet it, facebook it, instagram it, or even email it! Let everybody know that you're a part of GOAT Christmas - that you're a part of changing lives!</p>
          <a href="https://twitter.com/share" class="twitter-share-button" data-url="https://christmas.goattrips.org" data-text="I participated in GOAT Christmas! #goatchristmas" data-via="goattrips">Tweet</a>
<script>!function(d,s,id){var js,fjs=d.getElementsByTagName(s)[0],p=/^http:/.test(d.location)?'http':'https';if(!d.getElementById(id)){js=d.createElement(s);js.id=id;js.src=p+'://platform.twitter.com/widgets.js';fjs.parentNode.insertBefore(js,fjs);}}(document, 'script', 'twitter-wjs');</script>
          <div class="fb-like" data-href="https://christmas.goattrips.org" data-layout="standard" data-action="like" data-show-faces="true" data-share="true"></div>
        </div>
      <center>
        <a href="/">Go see what it looks like with your amount complete!</a>
      </center>
      <% end %>
    </div>
  </div>
</div>

@@goal
<div class="container">
  <div class="row">
    <div class="col-md-6 col-md-offset-3">
      <center>
        <h4>Our Christmas goal is currently at:</h4>
        <h1><b>$<%= @total %></b> of <b>$21,100</b></h1>
        <p>(from <%= @done.count %> donations)</p>
        <p><a href="/">Return to GOAT Christmas</a></p>
      </center>
    </div>
  </div>
</div>
