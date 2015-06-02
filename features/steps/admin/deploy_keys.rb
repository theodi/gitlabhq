class Spinach::Features::AdminDeployKeys < Spinach::FeatureSteps
  include SharedAuthentication
  include SharedPaths
  include SharedAdmin

  step 'there are public deploy keys in system' do
    create(:deploy_key, public: true)
    create(:another_deploy_key, public: true)
  end

  step 'I should see all public deploy keys' do
    DeployKey.are_public.each do |p|
      page.should have_content p.title
    end
  end

  step 'I click on first deploy key' do
    click_link DeployKey.are_public.first.title
  end

  step 'I should see deploy key details' do
    deploy_key = DeployKey.are_public.first
    current_path.should == admin_deploy_key_path(deploy_key)
    page.should have_content(deploy_key.title)
    page.should have_content(deploy_key.key)
  end

  step 'I visit admin deploy key page' do
    visit admin_deploy_key_path(deploy_key)
  end

  step 'I visit admin deploy keys page' do
    visit admin_deploy_keys_path
  end

  step 'I click \'New Deploy Key\'' do
    click_link 'New Deploy Key'
  end

  step 'I submit new deploy key' do
    fill_in "deploy_key_title", with: "laptop"
    fill_in "deploy_key_key", with: "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAzrEJUIR6Y03TCE9rIJ+GqTBvgb8t1jI9h5UBzCLuK4VawOmkLornPqLDrGbm6tcwM/wBrrLvVOqi2HwmkKEIecVO0a64A4rIYScVsXIniHRS6w5twyn1MD3sIbN+socBDcaldECQa2u1dI3tnNVcs8wi77fiRe7RSxePsJceGoheRQgC8AZ510UdIlO+9rjIHUdVN7LLyz512auAfYsgx1OfablkQ/XJcdEwDNgi9imI6nAXhmoKUm1IPLT2yKajTIC64AjLOnE0YyCh6+7RFMpiMyu1qiOCpdjYwTgBRiciNRZCH8xIedyCoAmiUgkUT40XYHwLuwiPJICpkAzp7Q== user@laptop"
    click_button "Create"
  end

  step 'I should be on admin deploy keys page' do
    current_path.should == admin_deploy_keys_path
  end

  step 'I should see newly created deploy key' do
    page.should have_content(deploy_key.title)
  end

  def deploy_key
    @deploy_key ||= DeployKey.are_public.first
  end
end
