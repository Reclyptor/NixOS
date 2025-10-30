{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    cmake
    gcc
    go
    jdk
    mongosh
    mysql84
    nodejs
    
    # Python with ML/CUDA packages for Hugging Face
    (python3.withPackages (ps: with ps; [
      torch-bin  # PyTorch with CUDA support
      torchvision-bin
      torchaudio-bin
      transformers  # Hugging Face Transformers
      accelerate    # Hugging Face Accelerate for distributed training
      datasets      # Hugging Face Datasets
      tokenizers    # Fast tokenizers
      sentencepiece # For some models
      protobuf      # Required by some models
      safetensors   # Safe tensor format
      huggingface-hub  # HF Hub for model downloads
      
      # Common ML dependencies
      numpy
      scipy
      pillow
      requests
      tqdm
      pyyaml
      
      # Optional but useful
      jupyter
      ipython
      matplotlib
      pandas
    ]))
  ];
  
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
