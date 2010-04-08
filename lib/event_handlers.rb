# Gem event handler callbacks,
# A method should exist here for every process supported by the system.
# Each method should share the same name w/ the corresponding process.
# Each method should take three parameters the gem/project which the event is being run on,
#  an array of process options associated w/ the event, and a hash of any parameter names/values
#  passed in when the event is invoked.
#
# Copyright (C) 2010 Red Hat, Inc.
# Written by Mohammed Morsi <mmorsi@redhat.com>
#
# This program is free software, you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation, either version 3
# of the License, or (at your option) any later version.
#
# You should have received a copy of the the GNU Affero
# General Public License, along with Polisher. If not, see
# <http://www.gnu.org/licenses/>

require 'erb'
require 'gem2rpm'
require 'net/smtp'

# TODO raise some exceptions of our own here (though not neccessary as event.run will rescue everything raised, it might help w/ debugging)

module EventHandlers

# Convert project into rpm package format.
def create_rpm_package(project, process_options = [''], optional_params = {})
   template_file = process_options[0]

   # open a handle to the spec file to write
   spec_file = ARTIFACTS_DIR + "/SPECS/#{project.name}.spec"
   sfh = File.open(spec_file, "wb")

   # d/l projects sources into artifacts/SOURCES dir
   project.download_to :dir => ARTIFACTS_DIR + "/SOURCES", :variables => optional_params

   # read template if specified
   template = (template_file == '' || template_file.nil?) ? nil : File.read_all(template_file)

   # if primary project source is a gem, process template w/ gem2rpm
   primary_source = project.primary_source
   if !primary_source.nil? && primary_source.source_type == "gem"
     gem_file_path = ARTIFACTS_DIR + '/SOURCES/' + primary_source.filename(optional_params)
     template = Gem2Rpm::TEMPLATE if template.nil?
     Gem2Rpm::convert gem_file_path, template, sfh

   # otherwise just process it w/ erb
   else
     # setting local variables to be pulled into erb via binding below
     params_s = ''
     optional_params.each { |k,v| params_s += "#{k} = '#{v}' ; " }
     eval params_s

     # take specified template_file and process it w/ erb,
     # TODO raise exception if we don't have a template
     template = File.read_all(template_file)
     template = ERB.new(template, 0, '<>').result(binding)

     # write to spec_file
     sfh.write template

   end

   sfh.close

   # run rpmbuild on spec
   system("rpmbuild --define '_topdir #{ARTIFACTS_DIR}' -ba #{spec_file}")
end

# Update specified yum repository w/ latest project artifact for specified version
def update_yum_repo(project, process_options, optional_params = {})
   repository = process_options[0]
   version = optional_params[:version]

   # create the repository dir if it doesn't exist
   repo_dir = ARTIFACTS_DIR + "/repos/#{repository}"
   Dir.mkdir repo_dir unless File.directory? repo_dir

   # get the latest built rpm that matches gem name
   project_src_rpm = Dir[ARTIFACTS_DIR + "/RPMS/*/#{project.name}-#{version}*.rpm"].
                             collect { |fn| File.new(fn) }.
                             sort { |f1,f2| file1.mtime <=> file2.mtime }.last
   project_tgt_rpm = "#{project.name}.rpm"

   # grab the architecture from the directory the src file resides in
   project_arch = project_src_rpm.path.split('.')
   project_arch = project_arch[project_arch.size-2]

   # copy project into repo/arch dir, creating it if it doesn't exist
   arch_dir = repo_dir + "/#{project_arch}"
   Dir.mkdir arch_dir unless File.directory? arch_dir
   File.write(arch_dir + "/#{project_tgt_rpm}", project_src_rpm.read)

   # run createrepo to finalize the repository
   system("createrepo #{repo_dir}")
end

end #module EventHandlers
