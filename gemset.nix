{
  ast = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0pp82blr5fakdk27d1d21xq9zchzb6vmyb1zcsl520s3ygvprn8m";
      type = "gem";
    };
    version = "2.3.0";
  };
  binding_of_caller = {
    dependencies = ["debug_inspector"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "15jg6dkaq2nzcd602d7ppqbdxw3aji961942w93crs6qw4n6h9yk";
      type = "gem";
    };
    version = "0.7.2";
  };
  childprocess = {
    dependencies = ["ffi"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1is253wm9k2s325nfryjnzdqv9flq8bm4y2076mhdrncxamrh7r2";
      type = "gem";
    };
    version = "0.5.9";
  };
  coderay = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "15vav4bhcc2x3jmi3izb11l4d9f3xv8hp2fszb7iqmpsccv1pz4y";
      type = "gem";
    };
    version = "1.1.2";
  };
  columnize = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1832r5nll855r125fkhp475m8bndk1ncna7hxs7la4lng2nnywxb";
      type = "gem";
    };
    version = "0.9.0";
  };
  coveralls = {
    dependencies = ["json" "simplecov" "term-ansicolor" "thor" "tins"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0akifzdykdbjlawkk3vbc9pxrw76g7dz5g9ankrvq8xhbw4crdnv";
      type = "gem";
    };
    version = "0.8.21";
  };
  debug_inspector = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0vxr0xa1mfbkfcrn71n7c4f2dj7la5hvphn904vh20j3x4j5lrx0";
      type = "gem";
    };
    version = "0.0.3";
  };
  debugger = {
    dependencies = ["columnize" "debugger-linecache" "debugger-ruby_core_source"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1rnh6kqwdvg024g3f0nrp9579hw0rqifb3sc01m4gwyy6x8bkwx4";
      type = "gem";
    };
    version = "1.6.8";
  };
  debugger-linecache = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0iwyx190fd5vfwj1gzr8pg3m374kqqix4g4fc4qw29sp54d3fpdz";
      type = "gem";
    };
    version = "1.2.0";
  };
  debugger-ruby_core_source = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1lp5dmm8a8dpwymv6r1y6yr24wxsj0gvgb2b8i7qq9rcv414snwd";
      type = "gem";
    };
    version = "1.3.8";
  };
  diff-lcs = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "18w22bjz424gzafv6nzv98h0aqkwz3d9xhm7cbr1wfbyas8zayza";
      type = "gem";
    };
    version = "1.3";
  };
  docile = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0m8j31whq7bm5ljgmsrlfkiqvacrw6iz9wq10r3gwrv5785y8gjx";
      type = "gem";
    };
    version = "1.1.5";
  };
  ffi = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "034f52xf7zcqgbvwbl20jwdyjwznvqnwpbaps9nk18v9lgb1dpx0";
      type = "gem";
    };
    version = "1.9.18";
  };
  json = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "01v6jjpvh3gnq6sgllpfqahlgxzj50ailwhj9b3cd20hi2dx0vxp";
      type = "gem";
    };
    version = "2.1.0";
  };
  kameleon-builder = {
    dependencies = ["childprocess" "psych" "ruby-graphviz" "table_print" "thor"];
  };
  method_source = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1g5i4w0dmlhzd18dijlqw5gk27bv6dj2kziqzrzb7mpgxgsd1sf2";
      type = "gem";
    };
    version = "0.8.2";
  };
  parallel = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0qv2yj4sxr36ga6xdxvbq9h05hn10bwcbkqv6j6q1fiixhsdnnzd";
      type = "gem";
    };
    version = "1.12.0";
  };
  parser = {
    dependencies = ["ast"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "130rfk8a2ws2fyq52hmi1n0xakylw39wv4x1qhai4z17x2b0k9cq";
      type = "gem";
    };
    version = "2.4.0.0";
  };
  powerpack = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1fnn3fli5wkzyjl4ryh0k90316shqjfnhydmc7f8lqpi0q21va43";
      type = "gem";
    };
    version = "0.1.1";
  };
  pry = {
    dependencies = ["coderay" "method_source" "slop"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "05xbzyin63aj2prrv8fbq2d5df2mid93m81hz5bvf2v4hnzs42ar";
      type = "gem";
    };
    version = "0.10.4";
  };
  pry-debugger = {
    dependencies = ["debugger" "pry"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1cis7csybc26kmq9j1p9p6dk4j2j70smq5dlrl2825819b5zjx9r";
      type = "gem";
    };
    version = "0.2.3";
  };
  pry-stack_explorer = {
    dependencies = ["binding_of_caller" "pry"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "10a529nz3pbn6by4f2mlrwnhg6amw0p2dphxljhmj0zkk9df3g5s";
      type = "gem";
    };
    version = "0.4.9.2";
  };
  psych = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1myf06a6kqxih0dgpdfhixmsb8h4pqb8y1iglppr39n6aln7vmga";
      type = "gem";
    };
    version = "2.2.4";
  };
  rainbow = {
    dependencies = ["rake"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "08w2ghc5nv0kcq5b257h7dwjzjz1pqcavajfdx2xjyxqsvh2y34w";
      type = "gem";
    };
    version = "2.2.2";
  };
  rake = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0mfqgpp3m69s5v1rd51lfh5qpjwyia5p4rg337pw8c8wzm6pgfsw";
      type = "gem";
    };
    version = "12.1.0";
  };
  rspec = {
    dependencies = ["rspec-core" "rspec-expectations" "rspec-mocks"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1nd50hycab2a2vdah9lxi585g8f63jxjvmzmxqyln51grxwx9hzb";
      type = "gem";
    };
    version = "3.6.0";
  };
  rspec-core = {
    dependencies = ["rspec-support"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "18np8wyw2g79waclpaacba6nd7x60ixg07ncya0j0qj1z9b37grd";
      type = "gem";
    };
    version = "3.6.0";
  };
  rspec-expectations = {
    dependencies = ["diff-lcs" "rspec-support"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "028ifzf9mqp3kxx40q1nbwj40g72g9zk0wr78l146phblkv96w0a";
      type = "gem";
    };
    version = "3.6.0";
  };
  rspec-mocks = {
    dependencies = ["diff-lcs" "rspec-support"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0nv6jkxy24sag1i9w9wi3850k6skk2fm6yhcrgnmlz6vmwxvizp8";
      type = "gem";
    };
    version = "3.6.0";
  };
  rspec-support = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "050paqqpsml8w88nf4a15zbbj3vvm471zpv73sjfdnz7w21wnypb";
      type = "gem";
    };
    version = "3.6.0";
  };
  rubocop = {
    dependencies = ["parallel" "parser" "powerpack" "rainbow" "ruby-progressbar" "unicode-display_width"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1mqyylfzch0967w7nfnqza84sqhljijd9y4bnq8hcmrscch75cxw";
      type = "gem";
    };
    version = "0.49.1";
  };
  ruby-graphviz = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0nxrwxgdawfwhnd10mmli9q73y3qpjnyy92769b74nh4xwb9w9bg";
      type = "gem";
    };
    version = "1.2.3";
  };
  ruby-progressbar = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1qzc7s7r21bd7ah06kskajc2bjzkr9y0v5q48y0xwh2l55axgplm";
      type = "gem";
    };
    version = "1.8.1";
  };
  simplecov = {
    dependencies = ["docile" "json" "simplecov-html"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1r9fnsnsqj432cmrpafryn8nif3x0qg9mdnvrcf0wr01prkdlnww";
      type = "gem";
    };
    version = "0.14.1";
  };
  simplecov-html = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1lihraa4rgxk8wbfl77fy9sf0ypk31iivly8vl3w04srd7i0clzn";
      type = "gem";
    };
    version = "0.10.2";
  };
  slop = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "00w8g3j7k7kl8ri2cf1m58ckxk8rn350gp4chfscmgv6pq1spk3n";
      type = "gem";
    };
    version = "3.6.0";
  };
  syck = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1xpl0ammwc0hhhc634lv90bp41jvmhirw71n7ihma6ghrq050qdm";
      type = "gem";
    };
    version = "1.3.0";
  };
  table_print = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1ibn9gji5fb6c9xmvm977y9k7r61yd9ypbsgxgr527rc9a8cs9v7";
      type = "gem";
    };
    version = "1.5.6";
  };
  term-ansicolor = {
    dependencies = ["tins"];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1b1wq9ljh7v3qyxkk8vik2fqx2qzwh5lval5f92llmldkw7r7k7b";
      type = "gem";
    };
    version = "1.6.0";
  };
  thor = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "01n5dv9kql60m6a00zc0r66jvaxx98qhdny3klyj0p3w34pad2ns";
      type = "gem";
    };
    version = "0.19.4";
  };
  tins = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "09whix5a7ics6787zrkwjmp16kqyh6560p9f317syks785805f7s";
      type = "gem";
    };
    version = "1.15.0";
  };
  unicode-display_width = {
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "12pi0gwqdnbx1lv5136v3vyr0img9wr0kxcn4wn54ipq4y41zxq8";
      type = "gem";
    };
    version = "1.3.0";
  };
}