class PasswordResetMailer < ApplicationMailer
  def reset_email(user, token)
    @user = user
    @reset_url = edit_password_reset_url(
      token: token,
      host: "yourcourtreport.com",
      protocol: "https"
    )

    mail(to: user.email, subject: "Reset your Court Report password")
  end
end
