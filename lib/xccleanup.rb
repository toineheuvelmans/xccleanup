require "xccleanup/version"

require 'fileutils'
require 'date'
require 'rubygems'

module Xccleanup
  
	# Helper functions

	$line_length = 80

	def self.line(char)
		puts char * $line_length
	end

	def self.center(text)
		if text.length > 0
			puts (' ' * (($line_length - text.length) / 2)) + text
		end
	end

	def self.prompt(*args)
	    print(*args)
	    gets
	end

	def self.prompt_bool(message)
		message = message + " (y/n) "
		input = prompt message
		input = input.strip!
		return input.casecmp("y") == 0 || input.casecmp("yes") == 0
	end

	def self.get_folders_in_dir(dir)
		if File.directory?(dir)
			return Dir.entries(dir).select {|entry| File.directory? File.join(dir,entry) and !(entry[0] =='.')}.map {|entry| File.join(dir,entry)}
		end
		return []
	end

	def self.get_files_in_dir(dir)
		if File.directory?(dir)
			return Dir.entries(dir).select {|entry| File.file? File.join(dir,entry)}.map {|entry| File.join(dir,entry)}
		end
		return []
	end

	def self.get_byte_size(file_or_dir)
		file_or_dir = file_or_dir
		if File.file? file_or_dir
			return File.stat(file_or_dir).size
		else
			cmd = "du -ks '#{file_or_dir}'"
			return (`#{cmd}`).split("\t").first.to_i * 1024
		end
	end

	def self.pbs(bytes)	# pretty byte size
		{
		  'B'  => 1024,
		  'KB' => 1024 * 1024,
		  'MB' => 1024 * 1024 * 1024,
		  'GB' => 1024 * 1024 * 1024 * 1024,
		  'TB' => 1024 * 1024 * 1024 * 1024 * 1024
		}.each do |e, s| 
			return "#{(bytes.to_f / (s / 1024)).round(1)} #{e}" if bytes < s
		end
	end

	#######################################################################
	# Cleanup functions

	def self.remove_derived_data(manually)
		saved_bytes = 0

		dd_dir = File.expand_path('~/Library/Developer/Xcode/DerivedData')
		dd_folders = get_folders_in_dir(dd_dir).sort_by{ |d| File.mtime(d) }.reverse
		if dd_folders.length > 1
			
			recent_projects = 0
			if manually
				recent_projects = prompt "> KEEP how many most recent projects? "
				recent_projects = recent_projects.to_i
			end

			kept = 0
			dd_folders.each do |folder_path|
				folder_name = folder_path.split('/').last
				if folder_name != 'ModuleCache'
					project_name = folder_name.rindex('-').nil? ? folder_name : folder_name[0,folder_name.rindex('-')]
					project_size = get_byte_size(folder_path)
					if kept < recent_projects
						puts "- Keeping #{project_name} (#{pbs(project_size)})"
					else
						puts "- Removing #{project_name} (#{pbs(project_size)})"
						FileUtils.rm_rf(folder_path)
						saved_bytes += project_size
					end
					kept += 1
				end
			end
		else
			puts "Skipping, no cleanup needed."
		end

		return saved_bytes
	end

	def self.remove_module_cache(manually)
		saved_bytes = 0

		puts "Removing Module Cache..."
		
		dd_dir = File.expand_path('~/Library/Developer/Xcode/DerivedData')
		path = File.join(dd_dir,'ModuleCache')
		saved_bytes = get_byte_size(path)

		get_folders_in_dir(path).each do |folder|
			FileUtils.rm_rf(folder)
		end

		return saved_bytes
	end


	def self.remove_device_support(manually)
		saved_bytes = 0

		ds_folder = File.expand_path('~/Library/Developer/Xcode/iOS DeviceSupport/')
		ds_versions = get_folders_in_dir(ds_folder).select { |folder| Gem::Version.correct?(folder.split('/').last.split(' ').first) }

		if ds_versions.length > 0
			puts "Found versions:"
			ds_versions.each do |version_folder|
				version_size = get_byte_size(version_folder)
				version_name = version_folder.split('/').last
				puts "• #{version_name} (#{pbs(version_size)})"
			end

			min_version = Gem::Version.new('9999.9.9')
			if manually
				min_version = prompt "> Miminum version to KEEP? "
				min_version = Gem::Version.new(min_version)
			end

			unless min_version.nil?
				ds_versions.each do |version_folder|
					version_name = version_folder.split('/').last
					version_number = version_name.split(' ').first
					version_number = Gem::Version.new(version_number)
					unless version_number.nil?
						if version_number < min_version
							puts "- Removing #{version_name}"
							saved_bytes += get_byte_size(version_folder)
							FileUtils.rm_rf(version_folder)
						else
							puts "- Keeping #{version_name}"
						end
					end
				end
			end
		end

		return saved_bytes
	end


	def self.remove_old_archives(manually)
		saved_bytes = 0

		arch_folder = File.expand_path('~/Library/Developer/Xcode/Archives/')
		arch_date_folders = get_folders_in_dir(arch_folder)

		bundle_ids = {}

		arch_date_folders.each do |arch_date_folder|
			date_name = arch_date_folder.split('/').last

			archives = get_folders_in_dir(arch_date_folder)


			if archives.length == 0
				puts "- Empty archives subfolder #{date_name}, removing..."
				FileUtils.rm_rf(arch_date_folder)
			else
				archives.each do |archive|
					plist_path = File.join(archive,'Info.plist')
					if File.file?(plist_path)
						plist = File.read(plist_path)

						bundle_id_pos = plist.index('<key>CFBundleIdentifier</key>')
						unless bundle_id_pos.nil?
							bundle_id_pos = plist.index('<string>', bundle_id_pos)
							unless bundle_id_pos.nil?
								bundle_id_pos = bundle_id_pos + 8 # <string>
								bundle_id_end = plist.index('</string>', bundle_id_pos)
								unless bundle_id_end.nil?
									bundle_id = plist[bundle_id_pos, bundle_id_end - bundle_id_pos]
									if bundle_ids[bundle_id].nil?
										bundle_ids[bundle_id] = {date_name => archive }
									else
										bundle_ids[bundle_id][date_name] = archive
									end
								end
							end
						end
					end
				end
			end
		end

		skip_single_archives = false
		if manually
			skip_single_archives = prompt_bool("Skip all bundle id's for which only a single archive is present?")
		end

		bundle_ids.each do |bundle_id, dates|
			if dates.length > 1
				dates = dates.sort_by { |date, archive| Date.parse(date) }.reverse
				puts "• #{dates.length} archives for \"#{bundle_id}\":"
				arch_index = 1
				dates.each do |date, archive|
					archive_size = get_byte_size(archive)
					puts "  #{arch_index}: #{date} (#{pbs(archive_size)})"
					arch_index += 1
				end
				
				recent = 0
				if manually
					recent = prompt("> KEEP how many most recent? ").to_i
				end

				if recent < dates.length
					kept = 0
					dates.each do |date, archive|
						if kept >= recent
							archive_size = get_byte_size(archive)
							puts "- Removing #{date}"
							FileUtils.rm_rf(archive)
							saved_bytes += archive_size
						else
							puts "- Keeping #{date}"
						end
						kept += 1
					end
				end
			elsif !skip_single_archives
				date, archive = dates.first
				archive_size = get_byte_size(archive)

				remove = !manually
				if manually
					remove = prompt_bool("• 1 archive for \"#{bundle_id}\" (#{date}, #{pbs(archive_size)})\n> REMOVE it?")
				else
					puts "• Removing 1 archive for \"#{bundle_id}\" (#{date}, #{pbs(archive_size)})"
				end

				if remove
					FileUtils.rm_rf(archive)
					saved_bytes += archive_size
				end
			end
		end

		return saved_bytes
	end


	def self.remove_expired_provisioning_profiles(manually)
		saved_bytes = 0

		pp_folder = File.expand_path('~/Library/MobileDevice/Provisioning Profiles')
		profiles = get_files_in_dir(pp_folder)

		today = Date.today

		profiles.each do |profile|
			escaped_profile = profile.gsub(/ /, '\ ')
			filename = profile.split('/').last
			ext = filename.split('.').last
			if ext == 'mobileprovision'
				cmd = "security cms -D -i #{escaped_profile}"
				plist = `#{cmd}`

				exp_date_pos = plist.index('<key>ExpirationDate</key>')
				unless exp_date_pos.nil?
					exp_date_pos = plist.index('<date>', exp_date_pos)
					unless exp_date_pos.nil?
						exp_date_pos = exp_date_pos + 6 # <date>
						exp_date_end = plist.index('</date>', exp_date_pos)
						unless exp_date_end.nil?
							exp_date_str = plist[exp_date_pos, exp_date_end - exp_date_pos]
							exp_date = Date.parse(exp_date_str)
							if today > exp_date
								puts "- Removing #{filename} (#{exp_date})"
								saved_bytes += get_byte_size(profile)
								FileUtils.rm(profile)
							else
								puts "- Skipping #{filename} (#{exp_date})"
							end
						end
					end
				end
			end
		end

		return saved_bytes
	end


	def self.remove_simulator_devices(manually)
		saved_bytes = 0

		sd_dir = File.expand_path('~/Library/Developer/CoreSimulator/Devices')

		devices_output = `xcrun simctl list devices`
		devices = devices_output.scan /\s\s\s\s(.*) \(([^)]+)\) (.*)/
		devices.each do |device|
			device_uuid = nil
			device.each do |device_component|
				device_uuid = /[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}/.match(device_component.downcase)
				
				unless device_uuid.nil?
					device_uuid = device_uuid[0].upcase
					break
				end
			end

			unavailable = false
			device.each do |device_component|
				if device_component.include? 'unavailable'
					unavailable = true
					break
				end
			end

			path = File.join(sd_dir, device_uuid)
			byte_size = get_byte_size(path)

			if unavailable || !manually || prompt_bool("> REMOVE #{device[0]} (#{pbs(byte_size)})?")
				if unavailable
					puts "! Unavailable device found: #{device[0]} (#{pbs(byte_size)})"
				end

		  		puts "- Removing device #{device[0]}"
		  		`xcrun simctl delete #{device_uuid}`
		  		saved_bytes += byte_size
		  	end
		end

		return saved_bytes
	end



	def self.remove_doc_sets(manually)
		saved_bytes = 0

		ds_dir = File.expand_path('~/Library/Developer/Shared/Documentation/DocSets')
		ds_folders = get_folders_in_dir(ds_dir)

		ds_folders.each do |ds_folder|
			docset_size = get_byte_size(ds_folder)
			docset_name = ds_folder.split('/').last
			if docset_name.split('.').last == 'docset'
				if !manually || prompt_bool("> REMOVE \"#{docset_name}\" (#{pbs(docset_size)})?")
					FileUtils.rm_rf(ds_folder)
					saved_bytes += docset_size
				end
			end
		end

		return saved_bytes
	end


	# Execution and Menu

	def self.run_steps(steps, manually)
		total_saved_bytes = 0

		steps.each do |method|
			puts "\n"
			line('-')
			method_name = "#{method.name}".gsub('_', ' ').capitalize
			center(method_name.upcase)
			line('-')
			saved_bytes = method.call(manually)
			line('.')
			center("#{method_name} completed, #{pbs(saved_bytes)} removed.")
			total_saved_bytes += saved_bytes
		end

		line('–')
		emoji = '😞'
		if total_saved_bytes > 0
			emoji = '👍'
		end
		mb = 1024 * 1024
		if total_saved_bytes > (100 * mb)
			emoji = '💪'
		end
		if total_saved_bytes > (5000 * mb)
			emoji = '🍾'
		end
		if total_saved_bytes > (10000 * mb)
			emoji = '💥'
		end
		center("🎉  XCODE CLEANUP completed, #{pbs(total_saved_bytes)} removed. #{emoji}")
		line('–')
	end


	def self.menu()
		line('–')
		center('🗑  XCODE CLEANUP 🗑')
		line('–')
		puts "This script can perform the following steps:\n"

		steps = [method(:remove_derived_data),
				 method(:remove_module_cache),
				 method(:remove_device_support),
				 method(:remove_old_archives),
				 method(:remove_expired_provisioning_profiles),
				 method(:remove_simulator_devices),
				 method(:remove_doc_sets)]

		step_index = 1
		steps.each do |method|
			method_name = "#{method.name}".gsub('_', ' ').capitalize
			puts "#{step_index}: #{method_name}"
			step_index += 1
		end

		puts "\nWhat would you like to do?\n"
		puts "[m] 🖐  Run each stap and manually specify what should be removed"
		puts "[n] 💥  Nuke'm, remove everything that can be removed"
		puts "[1-#{steps.length}] Run a single step"

		choice = prompt("(M/N/1-#{steps.length}): ").strip!

		if choice.casecmp('M') == 0
			puts "Running all steps manually"
			run_steps(steps, true)
		elsif choice.casecmp('N') == 0
			if prompt_bool("Are you sure you would like to Nuke'm?")
				run_steps(steps, false)
			end
		elsif choice.to_i > 0 && choice.to_i <= steps.length
			step = steps[choice.to_i - 1]
			method_name = "#{step.name}".gsub('_', ' ').capitalize
			puts "Running step #{choice.to_i}: #{method_name}"
			run_steps([step], true)
		end
	end

	self.menu()
  
end