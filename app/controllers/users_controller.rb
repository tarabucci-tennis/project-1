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

  def edit
    @user = User.find(params[:id])
  end

  def update
    @user = User.find(params[:id])
    if @user.update(user_params)
      redirect_to users_path, notice: "#{@user.name} was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    user = User.find(params[:id])
    user.destroy
    redirect_to users_path, notice: "#{user.name} was removed."
  end

  private

  def user_params
    permitted = params.expect(user: [ :name, :email, :admin, :password, :password_confirmation ])
    permitted.delete(:password) if permitted[:password].blank?
    permitted.delete(:password_confirmation) if permitted[:password].blank?
    permitted
  end
end
