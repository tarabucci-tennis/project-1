class PagesController < ApplicationController
  SABALENKA_QUOTES = [
    "I just want to keep fighting and keep believing.",
    "Every match is a new opportunity to show what I can do.",
    "I love the pressure. It makes me feel alive on the court.",
    "You have to believe in yourself even when no one else does.",
    "Losing is part of the journey. It makes winning so much sweeter.",
    "I play with my heart. That's the only way I know how.",
    "Champions are made in the moments when they want to quit but don't.",
    "I wake up every day wanting to be better than I was yesterday.",
    "Tennis is my life. I give everything I have every single time.",
    "The crowd gives me energy. I feed off their passion."
  ].freeze

  def home
    render "courtreport", layout: false
  end

  def tennis
    return redirect_to login_path unless current_user
    @quote = SABALENKA_QUOTES.sample
  end
end
