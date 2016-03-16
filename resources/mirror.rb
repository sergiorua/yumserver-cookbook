property :name, [String, Symbol], required: true, name_property: true
property :local_path, String, required: false
property :repo_name, String, required: true
property :repo_description, String, required: true
property :repo_baseurl, String, required: true
property :options, String, required: false
property :use_repo, [TrueClass, FalseClass], required: true, default: true

def real_local_path
  if local_path == NilClass
    "#{local_path}/#{name}/"
  else
    "/var/lib/yum-repo/#{name}/"
  end
end

action :create do
  template "/etc/reposync.repos.d/#{repo_name}.repo" do
    cookbook 'yumserver'
    source 'repo.erb'
    owner 'root'
    group 'root'
    mode '0644'
    variables(
      repo_name: repo_name,
      repo_description: repo_description,
      repo_baseurl: repo_baseurl
    )
    action :create
  end
  directory real_local_path do
    owner 'root'
    group 'root'
    mode '0755'
    action :create
  end
  ruby_block 'reposync' do
    block do
      YumServer::Helper.reposync(repo_name, real_local_path, options)
    end
    action :run
    only_if { ::File.exist?("/etc/reposync.repos.d/#{repo_name}.repo") }
  end
  ruby_block 'createrepo' do
    block do
      YumServer::Helper.createrepo(real_local_path)
    end
    action :run
  end
  if use_repo
    yum_repository repo_name do
      description repo_description
      baseurl "file://#{real_local_path}"
      gpgcheck false
      action :create
    end
  end
end

action :delete do
  file "/etc/reposync.repos.d/#{repo_name}.conf" do
    action :delete
  end
  directory real_local_path do
    recursive true
    action :delete
  end
  yum_repository repo_name do
    action :delete
  end
end
