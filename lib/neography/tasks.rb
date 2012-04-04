# borrowed from architect4r
require 'os'

# if using rails, install into environment-specific dir
def get_install_dir(rails_env)
  if rails_env
    install_dir = "neo4j_#{rails_env}"
    puts "Rails env detected, using install_dir #{install_dir}"
  else
    install_dir = "neo4j"
    puts "Rails env not detected, using install_dir #{install_dir}"
  end
  install_dir
end

# use this to get different server ports for rails envs
def daemon_port_prefix(env)
  case env.to_s.downcase
  when "development" then 74
  when "test"        then 75
  end
end

def replace_port(port_prefix, config_filename)
  # replace the first 2 digits of all ports with a different prefix
  puts "Replacing port prefix 74 with #{port_prefix}"
  %x[sed -i "" 's/port=74/port=#{port_prefix}/g' #{config_filename}]
end

namespace :neo4j do
  %w[test development].each do |env|
    namespace env do
      desc "Install Neo4j"
      task :install, :edition, :version do |t, args|
        args.with_defaults(:edition => "community", :version => "1.7.M02")

        if env
          puts "Installing Neo4j-#{args[:edition]}-#{args[:version]} with rails env #{env}"
        else
          puts "Installing Neo4j-#{args[:edition]}-#{args[:version]} without rails env"
        end

        install_dir = get_install_dir(env)
        
        if OS::Underlying.windows?
          # Download Neo4j    
          unless File.exist?('neo4j.zip')
            df = File.open('neo4j.zip', 'wb')
            begin
              df << HTTParty.get("http://dist.neo4j.org/neo4j-#{args[:edition]}-#{args[:version]}-windows.zip")
            ensure
              df.close()
            end
          end

          # Extract and move to neo4j directory
          unless File.exist?(install_dir)
            Zip::ZipFile.open('neo4j.zip') do |zip_file|
              zip_file.each do |f|
               f_path=File.join(".", f.name)
               FileUtils.mkdir_p(File.dirname(f_path))
               begin
                 zip_file.extract(f, f_path) unless File.exist?(f_path)
               rescue
                 puts f.name + " failed to extract."
               end
              end
            end
            FileUtils.mv "neo4j-#{args[:edition]}-#{args[:version]}", install_dir
         end

          # Install if running with Admin Privileges
          if %x[reg query "HKU\\S-1-5-19"].size > 0 
            %x[#{install_dir}/bin/neo4j install]
            puts "Neo4j Installed as a service."
          end

        else    
          %x[wget http://dist.neo4j.org/neo4j-#{args[:edition]}-#{args[:version]}-unix.tar.gz]
          %x[tar -xvzf neo4j-#{args[:edition]}-#{args[:version]}-unix.tar.gz]
          %x[mv neo4j-#{args[:edition]}-#{args[:version]} #{install_dir}]
          %x[rm neo4j-#{args[:edition]}-#{args[:version]}-unix.tar.gz]
          puts "Neo4j Installed in to #{install_dir} directory."
        end

        if env
          replace_port(daemon_port_prefix(env),
                       File.join(install_dir, "conf", "neo4j-server.properties"))
        end

        puts "Type 'rake neo4j:start' to start it"
      end
      
      desc "Start the Neo4j Server"
      task :start do
        install_dir = get_install_dir(env)

        puts "Starting Neo4j..."
        if OS::Underlying.windows? 
          if %x[reg query "HKU\\S-1-5-19"].size > 0 
            %x[#{install_dir}/bin/Neo4j.bat start]  #start service
          else
            puts "Starting Neo4j directly, not as a service."
            %x[#{install_dir}/bin/Neo4j.bat]
          end      
        else
          %x[#{install_dir}/bin/neo4j start]  
        end
      end
      
      desc "Stop the Neo4j Server"
      task :stop do
        install_dir = get_install_dir(env)

        puts "Stopping Neo4j..."
        if OS::Underlying.windows? 
          if %x[reg query "HKU\\S-1-5-19"].size > 0
             %x[#{install_dir}/bin/Neo4j.bat stop]  #stop service
          else
            puts "You do not have administrative rights to stop the Neo4j Service"   
          end
        else  
          %x[#{install_dir}/bin/neo4j stop]
        end
      end

      desc "Restart the Neo4j Server"
      task :restart do
        install_dir = get_install_dir(env)

        puts "Restarting Neo4j..."
        if OS::Underlying.windows? 
          if %x[reg query "HKU\\S-1-5-19"].size > 0
             %x[#{install_dir}/bin/Neo4j.bat restart] 
          else
            puts "You do not have administrative rights to restart the Neo4j Service"   
          end
        else  
          %x[#{install_dir}/bin/neo4j restart]
        end
      end

      desc "Reset the Neo4j Server"
      task :reset_yes_i_am_sure do
        install_dir = get_install_dir(env)

        # Stop the server
        if OS::Underlying.windows? 
          if %x[reg query "HKU\\S-1-5-19"].size > 0
             %x[#{install_dir}/bin/Neo4j.bat stop]
             
            # Reset the database
            FileUtils.rm_rf("#{install_dir}/data/graph.db")
            FileUtils.mkdir("#{install_dir}/data/graph.db")
            
            # Remove log files
            FileUtils.rm_rf("#{install_dir}/data/log")
            FileUtils.mkdir("#{install_dir}/data/log")

            %x[#{install_dir}/bin/Neo4j.bat start]
          else
            puts "You do not have administrative rights to reset the Neo4j Service"   
          end
        else  
          %x[#{install_dir}/bin/neo4j stop]
          
          # Reset the database
          FileUtils.rm_rf("#{install_dir}/data/graph.db")
          FileUtils.mkdir("#{install_dir}/data/graph.db")
          
          # Remove log files
          FileUtils.rm_rf("#{install_dir}/data/log")
          FileUtils.mkdir("#{install_dir}/data/log")
          
          # Start the server
          %x[#{install_dir}/bin/neo4j start]
        end
      end
    end
  end
end  
