import Authentication
import FluentMySQL
import Vapor
import Mailgun
import ServiceExt

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    // Register providers first
    try services.register(FluentMySQLProvider())
    try services.register(AuthenticationProvider())

    // Register routes to the router
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)

    // Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    // middlewares.use(SessionsMiddleware.self) // Enables sessions.
    // middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    services.register(middlewares)
    
    // Load env variables
    Environment.dotenv(filename: ".env")
    
    guard let dbHost: String = Environment.get("DB_HOST"),
        let dbPort: Int = Environment.get("DB_PORT"),
        let dbUsername: String = Environment.get("DB_USERNAME"),
        let dbPassword: String = Environment.get("DB_PASSWORD"),
        let dbName: String = Environment.get("DB_NAME") else {
        print("Unable to connect to DB server")
        throw Abort(.internalServerError)
    }

    // Configure a MySQL database
    let config = MySQLDatabaseConfig(
        hostname: dbHost,
        port: dbPort,
        username: dbUsername,
        password: dbPassword,
        database: dbName,
        capabilities: .default,
        characterSet: .utf8_general_ci,
        transport: .unverifiedTLS)
    let mysql = MySQLDatabase(config: config)

    // Register the configured MySQL database to the database config.
    var databases = DatabasesConfig()
    databases.enableLogging(on: .mysql)
    databases.add(database: mysql, as: .mysql)
    services.register(databases)

    /// Configure migrations
    var migrations = MigrationConfig()
    migrations.add(model: User.self, database: DatabaseIdentifier<User.Database>.mysql)
    migrations.add(model: UserToken.self, database: DatabaseIdentifier<UserToken.Database>.mysql)
    migrations.add(model: Customer.self, database: DatabaseIdentifier<Customer.Database>.mysql)
    migrations.add(model: Billing.self, database: DatabaseIdentifier<Billing.Database>.mysql)
    migrations.add(model: Product.self, database: DatabaseIdentifier<Product.Database>.mysql)
    migrations.add(model: MailConfig.self, database: DatabaseIdentifier<MailConfig.Database>.mysql)
    migrations.add(model: Invoice.self, database: DatabaseIdentifier<Invoice.Database>.mysql)
    migrations.add(model: InvoiceDetail.self, database: DatabaseIdentifier<InvoiceDetail.Database>.mysql)
    services.register(migrations)
    
    var content = ContentConfig.default()
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .deferredToDate
    content.use(encoder: encoder, for: .json)
    services.register(content)
    
    if let mailgunKey: String = Environment.get("MAILGUN") {
        let mailgunProvider = Mailgun(apiKey: mailgunKey)
        services.register(mailgunProvider)
    }
}
