# Velare E-Commerce Platform

A Flask-based e-commerce platform with buyer, seller, rider, and admin functionalities.

## Features

- **Buyer Features**: Browse products, shopping cart, checkout, order tracking, favorites
- **Seller Features**: Product management, sales reports, customer feedback, messaging
- **Rider Features**: Delivery management, earnings tracking, active deliveries
- **Admin Features**: User management, sales reports, voucher management, rider payouts

## Tech Stack

- **Backend**: Flask (Python)
- **Database**: Supabase (PostgreSQL)
- **Authentication**: bcrypt
- **File Handling**: Pillow
- **PDF Generation**: ReportLab
- **Excel Reports**: openpyxl

## Setup

### Prerequisites

- Python 3.10+
- Supabase account
- Git

### Installation

1. Clone the repository:
```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
cd YOUR_REPO_NAME
```

2. Create a virtual environment:
```bash
python -m venv venv
```

3. Activate the virtual environment:
   - Windows: `venv\Scripts\activate`
   - Linux/Mac: `source venv/bin/activate`

4. Install dependencies:
```bash
pip install -r requirements.txt
```

5. Create a `.env` file with your Supabase credentials:
```
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_key
```

6. Run the application:
```bash
python app.py
```

## Continuous Integration

This project uses GitHub Actions for CI/CD. The pipeline automatically:

- Runs on every push to `main` or `develop` branches
- Runs on pull requests
- Performs code linting with flake8
- Runs security scans with bandit
- Executes automated tests

### Setting up CI Secrets

To enable CI, add these secrets to your GitHub repository:

1. Go to your repository on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add the following secrets:
   - `SUPABASE_URL`: Your Supabase project URL
   - `SUPABASE_KEY`: Your Supabase anon/public key

## Docker Support

Run with Docker:

```bash
docker-compose up
```

See `DOCKER_SETUP.md` for detailed instructions.

## Testing

Run tests:
```bash
pytest tests/ -v
```

## Project Structure

```
├── blueprints/          # Flask blueprints (routes)
├── database/            # Database scripts and helpers
├── static/              # CSS, images, JavaScript
├── templates/           # HTML templates
├── tests/               # Test files
├── .github/workflows/   # CI/CD configuration
├── app.py               # Main application file
└── requirements.txt     # Python dependencies
```

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Commit your changes: `git commit -m 'Add feature'`
4. Push to the branch: `git push origin feature-name`
5. Open a pull request

## License

[Add your license here]
