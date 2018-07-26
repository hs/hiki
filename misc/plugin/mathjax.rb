# mathjax.rb: JathJax plugin for hiki

add_header_proc {
  s = <<EOS
  <script type="text/x-mathjax-config">
    MathJax.Hub.Config({
      tex2jax: {
        inlineMath: [['{$','$}']],
        processEscapes: true
      },
      CommonHTML: { matchFontHeight: false }
    });
  </script>
  <script src='https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.5/MathJax.js?config=TeX-MML-AM_CHTML' async></script>
EOS
}
