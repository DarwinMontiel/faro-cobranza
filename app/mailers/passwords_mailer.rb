class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: t(".subject", app: t("app.name")), to: user.email_address
  end
end
