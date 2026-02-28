User.find_or_create_by!(email: "tarabucci@gmail.com") do |u|
  u.name  = "Tara Bucci"
  u.admin = true
end

# Jody has no email yet — Tara will add it from the Players admin panel
User.find_or_create_by!(name: "Jody Staples", email: nil) do |u|
  u.admin = false
end
