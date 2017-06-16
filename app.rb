require 'sinatra'
if Sinatra::Base.development?
  require 'pry'
  require 'dotenv'
  Dotenv.load
end
require 'stripe'
require 'mail'
require_relative 'database'

Database.initialize

set :publishable_key, ENV['PUBLISHABLE_KEY']
set :secret_key, ENV['SECRET_KEY']
enable :sessions

Stripe.api_key = settings.secret_key

Mail.defaults do
  delivery_method :smtp, { :address   => "smtp.sendgrid.net",
                           :port      => 587,
                           :domain    => ENV['SENDGRID_DOMAIN'],
                           :user_name => ENV['SENDGRID_USER'],
                           :password  => ENV['SENDGRID_PW'],
                           :authentication => 'plain',
                           :enable_starttls_auto => true }
end

get '/' do
  @donations = Donation.all
  @done = Donation.all(:paid => 'true')
  @total = 0
  @done.each do |done|
    @total += done.amount
  end
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
  donation = @donation

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

  mail = Mail.deliver do

  to customer.email
  from 'Cam Hill <cam@eleosministry.com>'
  subject 'Thank you!'
  text_part do
    body "Thank you so much for your generous contribution to our \"shared space\" project! We believe this space will allow us to empower our neighbors in new and necessary ways as we continue the mission of Eleos in the Nicholtown community! This project is a lofty one, but we believe it's what God has called us to. And your generosity is a tangible reminder of God's faithfulness to us, as we step out in faith towards that call! We are beyond grateful for you and your generosity!

The Eleos Team


"
  end
  html_part do
    content_type 'text/html; charset=UTF-8'
    body "<p>Thank you so much for your generous contribution to our \"shared space\" project! We believe this space will allow us to empower our neighbors in new and necessary ways as we continue the mission of Eleos in the Nicholtown community! This project is a lofty one, but we believe it's what God has called us to. And your generosity is a tangible reminder of God's faithfulness to us, as we step out in faith towards that call! We are beyond grateful for you and your generosity!</p>

<p>The Eleos Team</p>"
  end
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
