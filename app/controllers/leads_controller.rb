class LeadsController < ApplicationController
  def create
    @lead = Lead.new(lead_params)

    if @lead.save
      flash[:success] = "Thank you for your interest! We'll be in touch soon."
      redirect_to root_path # Or a dedicated thank you page
    else
      # Errors will be accessible via @lead.errors
      # We need to ensure the form can be re-rendered with these errors.
      # For now, let's assume the form is on the homepage.
      flash.now[:error] = "There was a problem submitting your request: #{@lead.errors.full_messages.to_sentence}"
      # This render call assumes your homepage controller/action can handle re-rendering with @lead
      # and that the homepage view can display these errors. We'll address this when building the homepage.
      # For a simple setup, redirecting back with errors in flash might be easier if the form is on a separate page.
      # If the form is part of the homepage, we might need to render the homepage's template directly.
      # Let's aim to render the 'static_pages/home' template if it exists, or redirect with flash for now.
      # This part might need adjustment once the homepage is structured.
      render "static_pages/home", status: :unprocessable_entity # Assuming home is in static_pages
    end
  end

  private

  def lead_params
    params.require(:lead).permit(:name, :email, :company_name, :interest_details)
  end
end
