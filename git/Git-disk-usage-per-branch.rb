#
#   Written by Anthony O.
#   https://stackoverflow.com/users/535203/anthony-o
#   
#
#   Collected from
#   https://stackoverflow.com/questions/13722076/git-disk-usage-per-branch
#
#!/usr/bin/env ruby -w
require 'set'

display_branches = ARGV

packed_blobs = {}

class PackedBlob
    attr_accessor :sha, :type, :size, :packed_size, :offset, :depth, :base_sha, :is_shared, :branch
    def initialize(sha, type, size, packed_size, offset, depth, base_sha)
        @sha = sha
        @type = type
        @size = size
        @packed_size = packed_size
        @offset = offset
        @depth = depth
        @base_sha = base_sha
        @is_shared = false
        @branch = nil
    end
end

class Branch
    attr_accessor :name, :blobs, :non_shared_size, :non_shared_packed_size, :shared_size, :shared_packed_size, :non_shared_dependable_size, :non_shared_dependable_packed_size
    def initialize(name)
        @name = name
        @blobs = Set.new
        @non_shared_size = 0
        @non_shared_packed_size = 0
        @shared_size = 0
        @shared_packed_size = 0
        @non_shared_dependable_size = 0
        @non_shared_dependable_packed_size = 0
    end
end

dependable_blob_shas = Set.new

# Collect every packed blobs information
for pack_idx in Dir[".git/objects/pack/pack-*.idx"]
    IO.popen("git verify-pack -v #{pack_idx}", 'r') do |pack_list|
        pack_list.each_line do |pack_line|
            pack_line.chomp!
            if not pack_line.include? "delta"
                sha, type, size, packed_size, offset, depth, base_sha = pack_line.split(/\s+/, 7)
                size = size.to_i
                packed_size = packed_size.to_i
                packed_blobs[sha] = PackedBlob.new(sha, type, size, packed_size, offset, depth, base_sha)
                dependable_blob_shas.add(base_sha) if base_sha != nil
            else
                break
            end
        end
    end
end

branches = {}

# Now check all blobs for every branches in order to determine whether it's shared between branches or not
IO.popen("git branch --list", 'r') do |branch_list|
    branch_list.each_line do |branch_line|
        # For each branch
        branch_name = branch_line[2..-1].chomp
        branch = Branch.new(branch_name)
        branches[branch_name] = branch
        IO.popen("git rev-list #{branch_name}", 'r') do |rev_list|
            rev_list.each_line do |commit|
                # Look into each commit in order to collect all the blobs used
                for object in `git ls-tree -zrl #{commit}`.split("\0")
                    bits, type, sha, size, path = object.split(/\s+/, 5)
                    if type == 'blob'
                        blob = packed_blobs[sha]
                        branch.blobs.add(blob)
                        if not blob.is_shared
                            if blob.branch != nil and blob.branch != branch
                                # this blob has been used in another branch, let's set it to "shared"
                                blob.is_shared = true
                                blob.branch = nil
                            else
                                blob.branch = branch
                            end
                        end
                    end
                end
            end
        end
    end
end

# Now iterate on each branch to compute the space usage for each
branches.each_value do |branch|
    branch.blobs.each do |blob|
        if blob.is_shared
            branch.shared_size += blob.size
            branch.shared_packed_size += blob.packed_size
        else
            if dependable_blob_shas.include?(blob.sha)
                branch.non_shared_dependable_size += blob.size
                branch.non_shared_dependable_packed_size += blob.packed_size
            else
                branch.non_shared_size += blob.size
                branch.non_shared_packed_size += blob.packed_size
            end
        end
    end
    # Now print it if wanted
    if display_branches.empty? or display_branches.include?(branch.name)
        puts "branch: %s" % branch.name
        puts "\tnon shared:"
        puts "\t\tpacked: %s" % branch.non_shared_packed_size
        puts "\t\tnon packed: %s" % branch.non_shared_size
        puts "\tnon shared but with dependencies on it:"
        puts "\t\tpacked: %s" % branch.non_shared_dependable_packed_size
        puts "\t\tnon packed: %s" % branch.non_shared_dependable_size
        puts "\tshared:"
        puts "\t\tpacked: %s" % branch.shared_packed_size
        puts "\t\tnon packed: %s" % branch.shared_size, ""
    end
end