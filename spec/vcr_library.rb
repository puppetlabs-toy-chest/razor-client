# Useful things about our VCR tapes that needto be used by both the
# Rakefile and the spec_helper.

VCR_LIBRARY=File::join(File::dirname(__FILE__), 'fixtures', 'vcr')

def erase_vcr_library
  FileUtils.rm_rf VCR_LIBRARY
end
