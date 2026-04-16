class JoinsController < ApplicationController
  def show
    @team = TennisTeam.find_by(join_code: params[:code])
    unless @team
      redirect_to root_path, alert: "That join link isn't valid."
      return
    end

    unless current_user
      # Save the join code in session so the signup / sign-in flow
      # can consume it and auto-add the team.
      session[:pending_join_code] = params[:code]
      redirect_to signup_path,
                  notice: "Create your account to join #{@team.name} — already have one? Sign in instead."
      return
    end

    if @team.team_memberships.exists?(user: current_user)
      redirect_to team_path(@team), notice: "You're already on #{@team.name}!"
      return
    end

    # Placeholder-merge (the "Option C" fix): if the team has a same-name
    # seeded placeholder with no password, the signed-in user is almost
    # certainly a fresh signup who should BE that placeholder. Merge the
    # signed-in user's auth + child records onto the placeholder and
    # destroy the signed-in user, so existing lineup references and
    # match history stay intact. Re-sign-in as the placeholder.
    placeholder = @team.members
                       .where(password_digest: nil)
                       .where("LOWER(name) = ?", current_user.name.downcase)
                       .where.not(id: current_user.id)
                       .first

    if placeholder
      merge_current_user_into(placeholder)
      redirect_to team_path(@team),
                  notice: "Welcome! We matched your account to the team roster."
      return
    end

    TeamMembership.create!(user: current_user, tennis_team: @team, role: "player")
    redirect_to team_path(@team), notice: "You've joined #{@team.name}!"
  end

  private

  # Merge the currently-signed-in user into an existing placeholder
  # row on the team. Copies auth (email + password_digest + reset
  # token fields) onto the placeholder, moves over any child records
  # (team_memberships from other teams, availabilities, match_line_players),
  # destroys the signed-in user, and rewrites session[:user_id] to
  # the placeholder so the redirect lands them still signed in.
  def merge_current_user_into(placeholder)
    signed_in = current_user
    ActiveRecord::Base.transaction do
      # Capture the auth fields before we null them out on the signed-in
      # user. We need to free the email from the signed-in row first so
      # the uniqueness validation on User#email doesn't block us from
      # reassigning it to the placeholder.
      incoming_email             = signed_in.email
      incoming_password_digest   = signed_in.password_digest
      incoming_reset_token       = signed_in.reset_password_token
      incoming_reset_sent_at     = signed_in.reset_password_sent_at

      # Null out the signed-in user's email via update_column (bypasses
      # validations) so the placeholder can take it over below.
      signed_in.update_column(:email, nil)

      placeholder.update!(
        email:                  incoming_email,
        password_digest:        incoming_password_digest,
        reset_password_token:   incoming_reset_token,
        reset_password_sent_at: incoming_reset_sent_at
      )

      # Move the signed-in user's other team memberships onto the
      # placeholder, skipping any that the placeholder already has.
      signed_in.team_memberships.find_each do |tm|
        if placeholder.team_memberships.exists?(tennis_team_id: tm.tennis_team_id)
          tm.destroy
        else
          tm.update!(user: placeholder)
        end
      end

      Availability.where(user_id: signed_in.id).update_all(user_id: placeholder.id)
      MatchLinePlayer.where(user_id: signed_in.id).update_all(user_id: placeholder.id) rescue nil

      signed_in.destroy

      # Placeholder was already a team member (that's how we found it),
      # but belt-and-suspenders in case that changed during the merge.
      unless @team.team_memberships.exists?(user: placeholder)
        TeamMembership.create!(user: placeholder, tennis_team: @team, role: "player")
      end

      session[:user_id] = placeholder.id
    end
  end
end
