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

class Project < ActiveRecord::Base
  has_many :project_sources
  alias :sources :project_sources

  has_many :events

  validates_presence_of :name
  validates_uniqueness_of :name

  # Download all project sources to specified :dir
  def download_to(args = {})
    dir  = args.has_key?(:dir)  ? args[:dir]  : nil
    sources.each { |source| source.download_to :dir => dir }
  end
end
