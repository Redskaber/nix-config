# @path: ~/projects/configs/nix-config/home/core/app/office/pdf.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::app::office::pdf
# - poppler_utils: PDF rendering library
# - qpdf: C++ library and set of programs that inspect and manipulate the structure of PDF files
# - ocrmypdf: Adds an OCR text layer to scanned PDF files, allowing them to be searched

{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    poppler-utils
    qpdf
    ocrmypdf
  ];

}



