require 'mini_magick'
require 'pathname'

module Jekyll
  module JekyllMinimagick

    class GeneratedImageFile < Jekyll::StaticFile
      # Initialize a new GeneratedImage.
      #   +site+ is the Site
      #   +base+ is the String path to the <source>
      #   +dir+ is the String path between <source> and the file
      #   +name+ is the String filename of the file
      #   +preset+ is the Preset hash from the config.
      #
      # Returns <GeneratedImageFile>
      def initialize(site, base, dir, name, preset)
        @site = site
        @base = base
        @dir  = dir
        @name = name
        @dst_dir = preset.delete('destination')
        @src_dir = preset.delete('source')
        @commands = preset
      end

      # Obtains source file path by substituting the preset's source directory
      # for the destination directory.
      #
      # Returns source file path.
      def path
        File.join(@base, @dir.sub(@dst_dir, @src_dir), @name)
      end

      # Use MiniMagick to create a derivative image at the destination
      # specified (if the original is modified).
      #   +dest+ is the String path to the destination dir
      #
      # Returns false if the file was not modified since last time (no-op).
      def write(dest)
        dest_path = destination(dest)

        return false if File.exist? dest_path and !modified?

        self.class.mtimes[path] = mtime

        cache_path = File.join(@base, ".minimagick-cache", @dst_dir, @name)

        FileUtils.mkdir_p(File.dirname(cache_path))
        FileUtils.mkdir_p(File.dirname(dest_path))

        # If the file isn't cached, generate it
        if not (File.size? cache_path and File.stat(cache_path).mtime.to_i > mtime)
          image = ::MiniMagick::Image.open(path)
          @commands.each_pair do |command, arg|
            image.send command, arg
          end
          image.write cache_path
        end

        FileUtils.cp(cache_path, dest_path)

        true
      end

    end

    class MiniMagickGenerator < Generator
      safe true

      # Find all image files in the source directories of the presets specified
      # in the site config.  Add a GeneratedImageFile to the static_files stack
      # for later processing.
      def generate(site)
        return unless site.config['mini_magick']

        Jekyll.logger.info("MiniMagick plugin loaded.")

        site.config['mini_magick'].each_pair do |name, preset|
          src_dir = Pathname.new(site.source) + preset['source']
          Jekyll.logger.info("MiniMagicking #{name} from " +
                             "#{preset['source']} => #{preset['destination']}")

          Dir.glob(src_dir + "**" + "*.{png,jpg,jpeg,gif}") do |img|
            relative_img = Pathname.new(img).relative_path_from(src_dir)
            Jekyll.logger.debug("\t#{relative_img}")

            site.static_files << GeneratedImageFile.new(
              site, site.source, preset['destination'], relative_img.to_s, preset.clone)
          end
        end
      end
    end

  end
end
