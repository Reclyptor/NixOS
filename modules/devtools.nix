{ pkgs, ... }: 
let
  # Create a Python environment with overridden packages to avoid torch conflicts
  python = pkgs.python3.override {
    packageOverrides = self: super: {
      # Make torchvision and torchaudio use torch-bin instead of torch
      torch = super.torch-bin;
      torchvision = super.torchvision-bin;
      torchaudio = super.torchaudio-bin;
    };
  };
  
  pythonWithML = python.withPackages (ps: with ps; [
    torch  # This will use torch-bin due to override
    torchvision  # This will use torchvision-bin and depend on torch-bin
    torchaudio  # This will use torchaudio-bin and depend on torch-bin
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
  ]);
in {
  environment.systemPackages = with pkgs; [
    cmake
    gcc
    go
    jdk
    mongosh
    mysql84
    nodejs
    pythonWithML
  ];
  
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
