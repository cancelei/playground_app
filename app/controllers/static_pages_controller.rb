class StaticPagesController < ApplicationController
  def home
    @lead = Lead.new
  end
end
