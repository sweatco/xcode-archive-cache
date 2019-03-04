require 'zip'
require 'pathname'
require 'fileutils'

module XcodeArchiveCache
  module ArtifactCache
    class Archiver

      # @param [String] path
      # @param [String] destination
      #
      def archive(path, destination)
        if File.exists?(destination)
          raise ArgumentError.new, "Artifact cache path #{destination} is already taken"
        end

        if File.file?(path)
          archive_single_file(path, destination)
        elsif File.directory?(path)
          archive_directory(path, destination)
        else
          raise ArgumentError.new, "No artifact found at path #{path}"
        end
      end

      # @param [String] path
      # @param [String] destination
      #
      def unarchive(path, destination)
        unless File.file?(path)
          raise ArgumentError.new, "Artifact archive not found: #{path}"
        end

        unless File.directory?(destination)
          FileUtils.mkdir_p(destination)
        end

        Zip::File.open(path) do |archive|
          archive.each do |archive_entry|
            destination_file_path = File.join(destination, archive_entry.name)
            destination_dir_path = File.dirname(destination_file_path)
            unless File.exists?(destination_dir_path) && File.directory?(destination_dir_path)
              FileUtils.mkdir_p(destination_dir_path)
            end

            archive_entry.extract(destination_file_path)
          end
        end
      end

      private

      # @param [String] path
      # @param [String] destination
      #
      def archive_single_file(path, destination)
        Zip::File.open(destination, Zip::File::CREATE) do |archive|
          archive.add(File.basename(path), path)
        end
      end

      # @param [String] path
      # @param [String] destination
      #
      def archive_directory(path, destination)
        Zip::File.open(destination, Zip::File::CREATE) do |archive|
          add_entries(list_entries_in_directory(path), path, archive)
        end
      end

      # @param [Array<String>] entries
      # @param [String] root_dir
      # @param [Zip::File] archive
      #
      def add_entries(entries, root_dir, archive)
        entries.each do |entry|
          if File.directory?(entry)
            add_entries(list_entries_in_directory(entry), root_dir, archive)
          elsif File.file?(entry)
            add_single_file_entry(entry, root_dir, archive)
          else
            raise ArgumentError.new, "No file found at path #{entry}"
          end
        end
      end

      # @param [String] path
      #
      def list_entries_in_directory(path)
        (Dir.entries(path) - %w(. ..)).map {|entry| File.join(path, entry)}
      end

      # @param [String] path_on_disk
      # @param [String] root_dir
      # @param [Zip::File] archive
      #
      def add_single_file_entry(path_on_disk, root_dir, archive)
        file_path = Pathname.new(path_on_disk)
        root_dir_path = Pathname.new(root_dir)
        path_in_archive = file_path.relative_path_from(root_dir_path).to_s

        archive.get_output_stream(path_in_archive) do |stream|
          stream.write(File.open(path_on_disk, 'rb').read)
        end
      end
    end
  end
end
