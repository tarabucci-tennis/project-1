class UsersController < ApplicationController
  before_action :require_admin

  def index
    @users = User.order(:name)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to users_path, notice: "#{@user.name} was added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    user = User.find(params[:id])
    user.destroy
    redirect_to users_path, notice: "#{user.name} was removed."
  end

  private

  def user_params
    params.expect(user: [ :name, :email, :admin ])
  end
end
